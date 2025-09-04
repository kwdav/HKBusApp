#!/usr/bin/env python3
"""
終極優化版香港巴士數據收集
- KMB: 批量 API (3 次調用，超快)
- CTB: 並行處理優化 (ThreadPool，快很多)
- 智能快取與錯誤處理
"""

import requests
import json
import time
import threading
from datetime import datetime
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Any, Tuple

class OptimizedConcurrentBusDataCollector:
    def __init__(self):
        self.kmb_base = "https://data.etabus.gov.hk/v1/transport/kmb"
        self.ctb_base = "https://rt.data.gov.hk/v2/transport/citybus"
        
        # 線程安全的數據結構
        self.bus_data = {
            "generated_at": datetime.now().isoformat(),
            "routes": {},
            "stops": {},
            "route_stops": {},
            "stop_routes": {},
            "summary": {}
        }
        
        # 線程鎖
        self.data_lock = threading.Lock()
        self.stop_cache = set()  # 避免重複獲取站點
        
        # 統計
        self.stats = {
            'api_calls_made': 0,
            'successful_calls': 0,
            'failed_calls': 0,
            'cached_stops': 0
        }
        
        print("🚀 Optimized Concurrent Bus Data Collector initialized")
        print("📊 Strategy: KMB batch + CTB concurrent")
    
    def fetch_json(self, url: str, description: str = "", timeout: int = 30) -> Tuple[Dict[str, Any], float]:
        """線程安全的 JSON 獲取"""
        try:
            start_time = time.time()
            response = requests.get(url, timeout=timeout)
            response.raise_for_status()
            data = response.json()
            
            elapsed = time.time() - start_time
            
            with self.data_lock:
                self.stats['api_calls_made'] += 1
                self.stats['successful_calls'] += 1
            
            return data, elapsed
        except Exception as e:
            with self.data_lock:
                self.stats['api_calls_made'] += 1
                self.stats['failed_calls'] += 1
            
            print(f"❌ {description}: {e}")
            return {}, 0
    
    def collect_kmb_batch(self):
        """KMB 批量收集 (保持原有高效方式)"""
        print("\n🏎️  KMB Ultra-Fast Collection (3 API calls)")
        print("=" * 50)
        
        start_time = time.time()
        
        # 1. 批量獲取所有站點
        print("1️⃣ Fetching ALL KMB stops...")
        all_stops, stops_time = self.fetch_json(f"{self.kmb_base}/stop", "All KMB stops")
        
        if not all_stops.get('data'):
            print("❌ Failed to get KMB stops")
            return False
        
        stops_index = {stop['stop']: stop for stop in all_stops['data']}
        print(f"✅ Got {len(stops_index):,} stops in {stops_time:.2f}s")
        
        # 2. 批量獲取所有路線
        print("\n2️⃣ Fetching ALL KMB routes...")
        all_routes, routes_time = self.fetch_json(f"{self.kmb_base}/route", "All KMB routes")
        
        if not all_routes.get('data'):
            print("❌ Failed to get KMB routes")
            return False
        
        routes_index = {}
        for route in all_routes['data']:
            key = f"{route['route']}_{route['bound']}_{route['service_type']}"
            routes_index[key] = route
        print(f"✅ Got {len(routes_index):,} route variations in {routes_time:.2f}s")
        
        # 3. 批量獲取所有路線站點映射
        print("\n3️⃣ Fetching ALL KMB route-stops...")
        all_route_stops, mapping_time = self.fetch_json(f"{self.kmb_base}/route-stop", "All KMB route-stops")
        
        if not all_route_stops.get('data'):
            print("❌ Failed to get KMB route-stops")
            return False
        
        print(f"✅ Got {len(all_route_stops['data']):,} mappings in {mapping_time:.2f}s")
        
        # 4. 高效處理數據
        print("\n⚡ Processing KMB data...")
        route_stops_map = defaultdict(list)
        used_stops = set()
        
        for route_stop in all_route_stops['data']:
            route_num = route_stop['route']
            bound = route_stop['bound']
            service_type = route_stop['service_type']
            stop_id = route_stop['stop']
            sequence = route_stop['seq']
            
            route_key = f"{route_num}_{bound}_{service_type}"
            unique_route_id = f"KMB_{route_num}_{bound}"
            
            route_stops_map[unique_route_id].append({
                'stop_id': stop_id,
                'sequence': sequence
            })
            
            used_stops.add(stop_id)
            
            # 創建路線資料
            if unique_route_id not in self.bus_data['routes'] and route_key in routes_index:
                route_info = routes_index[route_key]
                self.bus_data['routes'][unique_route_id] = {
                    'route_number': route_num,
                    'company': 'KMB',
                    'direction': 'inbound' if bound == 'I' else 'outbound',
                    'origin_tc': route_info['orig_tc'],
                    'origin_en': route_info['orig_en'],
                    'dest_tc': route_info['dest_tc'],
                    'dest_en': route_info['dest_en'],
                    'service_type': service_type
                }
        
        # 添加站點資料
        for stop_id in used_stops:
            if stop_id in stops_index:
                stop_data = stops_index[stop_id]
                self.bus_data['stops'][stop_id] = {
                    'name_tc': stop_data['name_tc'],
                    'name_en': stop_data['name_en'],
                    'latitude': float(stop_data['lat']),
                    'longitude': float(stop_data['long']),
                    'company': 'KMB'
                }
                self.stop_cache.add(stop_id)
        
        # 整理路線站點
        for route_id, stops in route_stops_map.items():
            stops.sort(key=lambda x: x['sequence'])
            self.bus_data['route_stops'][route_id] = stops
        
        kmb_time = time.time() - start_time
        print(f"✅ KMB Complete: {len(self.bus_data['routes'])} routes, {len(used_stops)} stops in {kmb_time:.2f}s")
        
        return True
    
    def fetch_ctb_route_stops(self, company: str, route_id: str, direction: str) -> Dict[str, Any]:
        """獲取單個路線的站點"""
        unique_route_id = f"{company}_{route_id}_{direction[0].upper()}"
        
        try:
            # 獲取路線站點
            stops_data, _ = self.fetch_json(
                f"{self.ctb_base}/route-stop/{company}/{route_id}/{direction}",
                f"{company} {route_id} {direction}"
            )
            
            if not stops_data.get('data'):
                return {'route_id': unique_route_id, 'stops': []}
            
            route_stops = []
            new_stops = []
            
            for stop_info in stops_data['data']:
                stop_id = stop_info['stop']
                sequence = stop_info['seq']
                
                route_stops.append({
                    'stop_id': stop_id,
                    'sequence': sequence
                })
                
                # 檢查是否需要獲取站點詳情
                if stop_id not in self.stop_cache:
                    new_stops.append(stop_id)
                    self.stop_cache.add(stop_id)
            
            # 並行獲取新站點詳情
            if new_stops:
                stop_details = self.fetch_stop_details_concurrent(company, new_stops)
                
                with self.data_lock:
                    for stop_detail in stop_details:
                        if stop_detail:
                            self.bus_data['stops'][stop_detail['stop_id']] = stop_detail
            
            return {
                'route_id': unique_route_id,
                'stops': sorted(route_stops, key=lambda x: x['sequence'])
            }
            
        except Exception as e:
            print(f"❌ Error processing {company} {route_id} {direction}: {e}")
            return {'route_id': unique_route_id, 'stops': []}
    
    def fetch_stop_details_concurrent(self, company: str, stop_ids: List[str]) -> List[Dict[str, Any]]:
        """並行獲取站點詳情"""
        results = []
        
        def fetch_single_stop(stop_id):
            stop_detail, _ = self.fetch_json(
                f"{self.ctb_base}/stop/{stop_id}",
                f"{company} stop {stop_id}"
            )
            
            if stop_detail.get('data'):
                stop_data = stop_detail['data']
                return {
                    'stop_id': stop_id,
                    'name_tc': stop_data['name_tc'],
                    'name_en': stop_data['name_en'],
                    'latitude': float(stop_data['lat']),
                    'longitude': float(stop_data['long']),
                    'company': company
                }
            return None
        
        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = {executor.submit(fetch_single_stop, stop_id): stop_id for stop_id in stop_ids}
            
            for future in as_completed(futures):
                result = future.result()
                if result:
                    results.append(result)
        
        return results
    
    def collect_ctb_concurrent(self):
        """CTB 並行收集"""
        print("\n🚌 CTB Concurrent Collection")
        print("=" * 40)
        
        start_time = time.time()
        
        # 獲取 CTB 路線列表
        print("📋 Fetching CTB routes...")
        ctb_routes_data, _ = self.fetch_json(f"{self.ctb_base}/route/CTB", "CTB routes")
        
        if not ctb_routes_data.get('data'):
            print("❌ No CTB routes found")
            return False
        
        routes = ctb_routes_data['data']
        print(f"✅ Found {len(routes)} CTB routes")
        
        # 創建任務列表 (每個路線的兩個方向)
        tasks = []
        for route_info in routes:
            route_id = route_info['route']
            
            # 添加路線資料
            for direction, dir_code in [('inbound', 'I'), ('outbound', 'O')]:
                unique_route_id = f"CTB_{route_id}_{dir_code}"
                
                with self.data_lock:
                    self.bus_data['routes'][unique_route_id] = {
                        'route_number': route_id,
                        'company': 'CTB',
                        'direction': direction,
                        'origin_tc': route_info['orig_tc'],
                        'origin_en': route_info['orig_en'],
                        'dest_tc': route_info['dest_tc'],
                        'dest_en': route_info['dest_en']
                    }
                
                tasks.append(('CTB', route_id, direction))
        
        print(f"📊 Processing {len(tasks)} route directions with ThreadPool...")
        
        # 並行處理 CTB 路線
        successful_routes = 0
        with ThreadPoolExecutor(max_workers=10) as executor:
            # 提交所有任務
            future_to_task = {
                executor.submit(self.fetch_ctb_route_stops, company, route_id, direction): (company, route_id, direction)
                for company, route_id, direction in tasks
            }
            
            # 處理結果
            for i, future in enumerate(as_completed(future_to_task)):
                if i % 50 == 0:
                    print(f"   Progress: {i}/{len(tasks)} ({i/len(tasks)*100:.1f}%)")
                
                try:
                    result = future.result()
                    if result['stops']:
                        with self.data_lock:
                            self.bus_data['route_stops'][result['route_id']] = result['stops']
                        successful_routes += 1
                except Exception as e:
                    task = future_to_task[future]
                    print(f"❌ Failed {task}: {e}")
        
        ctb_time = time.time() - start_time
        print(f"✅ CTB Complete: {successful_routes} routes processed in {ctb_time:.2f}s")
        
        return successful_routes > 0
    
    def create_reverse_mapping(self):
        """創建站點→路線反向映射"""
        print("\n🔄 Creating stop-to-routes mapping...")
        
        for route_id, stops in self.bus_data['route_stops'].items():
            route_info = self.bus_data['routes'][route_id]
            
            for stop_info in stops:
                stop_id = stop_info['stop_id']
                
                if stop_id not in self.bus_data['stop_routes']:
                    self.bus_data['stop_routes'][stop_id] = []
                
                self.bus_data['stop_routes'][stop_id].append({
                    'route_number': route_info['route_number'],
                    'company': route_info['company'],
                    'direction': route_info['direction'],
                    'destination': route_info['dest_tc'],
                    'sequence': stop_info['sequence'],
                    'route_id': route_id
                })
        
        print(f"✅ Created mappings for {len(self.bus_data['stop_routes'])} stops")
    
    def finalize_and_save(self, filename: str = "bus_data_optimized_concurrent.json"):
        """完成並保存數據"""
        print("\n📊 Finalizing data...")
        
        # 統計
        self.bus_data['summary'] = {
            'total_routes': len(self.bus_data['routes']),
            'total_stops': len(self.bus_data['stops']),
            'total_stop_route_mappings': len(self.bus_data['stop_routes']),
            'kmb_routes': len([r for r in self.bus_data['routes'] if r.startswith('KMB')]),
            'ctb_routes': len([r for r in self.bus_data['routes'] if r.startswith('CTB')]),
            'api_calls_made': self.stats['api_calls_made'],
            'success_rate': f"{(self.stats['successful_calls']/self.stats['api_calls_made']*100):.1f}%" if self.stats['api_calls_made'] > 0 else "0%"
        }
        
        summary = self.bus_data['summary']
        print(f"\n📈 Final Statistics:")
        print(f"   🚌 Total Routes: {summary['total_routes']:,}")
        print(f"      ├─ KMB: {summary['kmb_routes']:,}")
        print(f"      └─ CTB: {summary['ctb_routes']:,}")
        print(f"   📍 Total Stops: {summary['total_stops']:,}")
        print(f"   🗺️  Stop-Route Mappings: {summary['total_stop_route_mappings']:,}")
        print(f"   📡 API Calls: {summary['api_calls_made']:,} (Success: {summary['success_rate']})")
        
        # 保存數據
        print(f"\n💾 Saving to {filename}...")
        start_time = time.time()
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(self.bus_data, f, ensure_ascii=False, indent=2)
        
        save_time = time.time() - start_time
        
        import os
        file_size = os.path.getsize(filename)
        print(f"✅ Saved in {save_time:.2f}s")
        print(f"📁 File: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")
        
        return filename

def main():
    """主執行函數"""
    print("🚀 Optimized Concurrent Hong Kong Bus Data Collection")
    print("⚡ KMB: Batch API (ultra-fast) + CTB: Concurrent processing")
    print("=" * 70)
    
    start_time = time.time()
    collector = OptimizedConcurrentBusDataCollector()
    
    try:
        # 1. KMB 批量收集 (超快)
        if not collector.collect_kmb_batch():
            print("❌ KMB collection failed")
            return
        
        # 2. CTB 並行收集 (優化)
        if not collector.collect_ctb_concurrent():
            print("❌ CTB collection failed")
            return
        
        # 3. 創建反向映射
        collector.create_reverse_mapping()
        
        # 4. 完成並保存
        filename = collector.finalize_and_save()
        
        total_time = time.time() - start_time
        print("\n" + "=" * 70)
        print(f"🎉 Collection Complete in {total_time:.2f} seconds!")
        print(f"📄 Output: {filename}")
        print("⚡ Ready for iOS app integration!")
        
    except KeyboardInterrupt:
        print("\n⏸️  Collection interrupted by user")
    except Exception as e:
        print(f"\n💥 Error: {e}")
        raise

if __name__ == "__main__":
    main()