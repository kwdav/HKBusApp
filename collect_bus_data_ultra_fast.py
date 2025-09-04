#!/usr/bin/env python3
"""
超高效香港巴士數據收集腳本 - 批量 API 版本
優化重點：
1. KMB: 只用 2 次 API 調用獲取全部數據 (vs 原來數百次)
2. CTB/NWFB: 最小化 API 調用
3. 記憶體優化處理大量數據
4. 進度追蹤與錯誤處理
"""

import requests
import json
import time
from datetime import datetime
from collections import defaultdict
from typing import Dict, List, Any

class UltraFastBusDataCollector:
    def __init__(self):
        self.kmb_base = "https://data.etabus.gov.hk/v1/transport/kmb"
        self.ctb_base = "https://rt.data.gov.hk/v2/transport/citybus"
        
        # 最終數據結構
        self.bus_data = {
            "generated_at": datetime.now().isoformat(),
            "routes": {},
            "stops": {},
            "route_stops": {},
            "stop_routes": {},
            "summary": {}
        }
        
        print("🚀 Ultra-Fast Bus Data Collector initialized")
        print("📊 Target: Complete HK bus data in minimal API calls")
    
    def fetch_json(self, url: str, description: str) -> Dict[str, Any]:
        """高效 JSON 獲取"""
        try:
            print(f"📡 {description}...")
            start_time = time.time()
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            elapsed = time.time() - start_time
            record_count = len(data.get('data', [])) if 'data' in data else 0
            print(f"✅ Got {record_count:,} records in {elapsed:.2f}s")
            return data
        except Exception as e:
            print(f"❌ Error: {e}")
            return {}
    
    def collect_kmb_ultra_fast(self):
        """超快速 KMB 數據收集 - 只需 3 次 API 調用！"""
        print("\n🏎️  KMB Ultra-Fast Collection (3 API calls total)")
        print("=" * 50)
        
        # 1️⃣ 獲取所有站點 (一次調用)
        print("1️⃣ Batch fetching ALL KMB stops...")
        all_stops = self.fetch_json(f"{self.kmb_base}/stop", "All KMB stops")
        
        if not all_stops.get('data'):
            print("❌ Failed to get KMB stops")
            return False
        
        # 建立站點索引 (O(1) 查找)
        stops_index = {stop['stop']: stop for stop in all_stops['data']}
        print(f"📍 Indexed {len(stops_index):,} stops")
        
        # 2️⃣ 獲取所有路線資料 (一次調用)
        print("\n2️⃣ Batch fetching ALL KMB routes...")
        all_routes = self.fetch_json(f"{self.kmb_base}/route", "All KMB routes")
        
        if not all_routes.get('data'):
            print("❌ Failed to get KMB routes")
            return False
        
        # 建立路線索引
        routes_index = {}
        for route in all_routes['data']:
            key = f"{route['route']}_{route['bound']}_{route['service_type']}"
            routes_index[key] = route
        print(f"🚌 Indexed {len(routes_index):,} route variations")
        
        # 3️⃣ 獲取所有路線站點映射 (一次調用)
        print("\n3️⃣ Batch fetching ALL KMB route-stops...")
        all_route_stops = self.fetch_json(f"{self.kmb_base}/route-stop", "All KMB route-stops")
        
        if not all_route_stops.get('data'):
            print("❌ Failed to get KMB route-stops")
            return False
        
        print(f"\n⚡ Processing {len(all_route_stops['data']):,} route-stop mappings...")
        
        # 🔥 高效數據處理 (記憶體優化)
        route_stops_map = defaultdict(list)
        used_stops = set()
        processed_routes = 0
        
        # 批量處理所有映射關係
        for i, route_stop in enumerate(all_route_stops['data']):
            if i % 10000 == 0:  # 進度顯示
                print(f"   Progress: {i:,}/{len(all_route_stops['data']):,} ({i/len(all_route_stops['data'])*100:.1f}%)")
            
            route_num = route_stop['route']
            bound = route_stop['bound']
            service_type = route_stop['service_type']
            stop_id = route_stop['stop']
            sequence = route_stop['seq']
            
            route_key = f"{route_num}_{bound}_{service_type}"
            unique_route_id = f"KMB_{route_num}_{bound}"
            
            # 添加到路線站點映射
            route_stops_map[unique_route_id].append({
                'stop_id': stop_id,
                'sequence': sequence
            })
            
            used_stops.add(stop_id)
            
            # 創建路線資料 (避免重複)
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
                processed_routes += 1
        
        # 只添加使用的站點 (記憶體優化)
        print(f"\n📍 Adding {len(used_stops):,} used stops...")
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
        
        # 整理並排序路線站點
        print("🔄 Sorting route stops...")
        for route_id, stops in route_stops_map.items():
            stops.sort(key=lambda x: x['sequence'])
            self.bus_data['route_stops'][route_id] = stops
        
        print(f"\n✅ KMB Collection Complete:")
        print(f"   📊 Routes: {processed_routes:,}")
        print(f"   📍 Stops: {len(used_stops):,}")
        print(f"   🗺️  Route-Stop mappings: {len(route_stops_map):,}")
        
        return True
    
    def collect_ctb_optimized(self):
        """優化的 CTB/NWFB 數據收集"""
        print("\n🚌 CTB/NWFB Optimized Collection")
        print("=" * 40)
        
        companies = ['CTB', 'NWFB']
        total_processed = 0
        
        for company in companies:
            print(f"\n📋 Processing {company}...")
            
            # 獲取該公司所有路線
            routes_data = self.fetch_json(
                f"{self.ctb_base}/route/{company}", 
                f"{company} all routes"
            )
            
            if not routes_data.get('data'):
                print(f"❌ No {company} routes found")
                continue
            
            routes = routes_data['data']
            print(f"📊 Processing {len(routes)} {company} routes...")
            
            for i, route_info in enumerate(routes):
                if i % 10 == 0:
                    print(f"   Progress: {i}/{len(routes)} ({i/len(routes)*100:.1f}%)")
                
                route_id = route_info['route']
                
                # 處理兩個方向
                for direction, dir_code in [('inbound', 'I'), ('outbound', 'O')]:
                    unique_route_id = f"{company}_{route_id}_{dir_code}"
                    
                    # 添加路線資料
                    self.bus_data['routes'][unique_route_id] = {
                        'route_number': route_id,
                        'company': company,
                        'direction': direction,
                        'origin_tc': route_info['orig_tc'],
                        'origin_en': route_info['orig_en'],
                        'dest_tc': route_info['dest_tc'],
                        'dest_en': route_info['dest_en']
                    }
                    
                    # 獲取該方向的站點
                    stops_data = self.fetch_json(
                        f"{self.ctb_base}/route-stop/{company}/{route_id}/{direction}",
                        f"{company} {route_id} {direction}"
                    )
                    
                    if not stops_data.get('data'):
                        continue
                    
                    route_stops = []
                    for stop_info in stops_data['data']:
                        stop_id = stop_info['stop']
                        sequence = stop_info['seq']
                        
                        route_stops.append({
                            'stop_id': stop_id,
                            'sequence': sequence
                        })
                        
                        # 獲取站點詳情 (如果未有)
                        if stop_id not in self.bus_data['stops']:
                            stop_detail = self.fetch_json(
                                f"{self.ctb_base}/stop/{stop_id}",
                                f"{company} stop {stop_id}"
                            )
                            
                            if stop_detail.get('data'):
                                stop_data = stop_detail['data']
                                self.bus_data['stops'][stop_id] = {
                                    'name_tc': stop_data['name_tc'],
                                    'name_en': stop_data['name_en'],
                                    'latitude': float(stop_data['lat']),
                                    'longitude': float(stop_data['long']),
                                    'company': company
                                }
                            
                            # 小延遲避免 API 限制
                            time.sleep(0.02)
                    
                    # 排序並儲存
                    route_stops.sort(key=lambda x: x['sequence'])
                    self.bus_data['route_stops'][unique_route_id] = route_stops
                    total_processed += 1
            
            print(f"✅ {company} Complete: {len([r for r in self.bus_data['routes'] if r.startswith(company)])} routes")
        
        return total_processed > 0
    
    def create_reverse_mapping(self):
        """創建站點→路線反向映射 (快速查找)"""
        print("\n🔄 Creating stop-to-routes mapping...")
        
        mapping_count = 0
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
                mapping_count += 1
        
        print(f"✅ Created {mapping_count:,} stop-route mappings")
    
    def finalize_data(self):
        """完成數據處理"""
        print("\n📊 Finalizing data...")
        
        # 添加統計摘要
        self.bus_data['summary'] = {
            'total_routes': len(self.bus_data['routes']),
            'total_stops': len(self.bus_data['stops']),
            'total_stop_route_mappings': len(self.bus_data['stop_routes']),
            'kmb_routes': len([r for r in self.bus_data['routes'] if r.startswith('KMB')]),
            'ctb_routes': len([r for r in self.bus_data['routes'] if r.startswith('CTB')]),
            'nwfb_routes': len([r for r in self.bus_data['routes'] if r.startswith('NWFB')])
        }
        
        summary = self.bus_data['summary']
        print(f"\n📈 Final Statistics:")
        print(f"   🚌 Total Routes: {summary['total_routes']:,}")
        print(f"      ├─ KMB: {summary['kmb_routes']:,}")
        print(f"      ├─ CTB: {summary['ctb_routes']:,}")
        print(f"      └─ NWFB: {summary['nwfb_routes']:,}")
        print(f"   📍 Total Stops: {summary['total_stops']:,}")
        print(f"   🗺️  Stop-Route Mappings: {summary['total_stop_route_mappings']:,}")
    
    def save_data(self, filename: str = "bus_data_ultra_fast.json"):
        """保存數據"""
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
    print("🚀 Ultra-Fast Hong Kong Bus Data Collection")
    print("⚡ Optimized for minimal API calls & maximum speed")
    print("=" * 60)
    
    start_time = time.time()
    collector = UltraFastBusDataCollector()
    
    try:
        # 1. 超快速 KMB 數據收集 (3 API calls)
        if not collector.collect_kmb_ultra_fast():
            print("❌ KMB collection failed")
            return
        
        # 2. 優化的 CTB/NWFB 收集
        if not collector.collect_ctb_optimized():
            print("❌ CTB/NWFB collection failed")
            return
        
        # 3. 創建反向映射
        collector.create_reverse_mapping()
        
        # 4. 完成數據處理
        collector.finalize_data()
        
        # 5. 保存數據
        filename = collector.save_data()
        
        total_time = time.time() - start_time
        print("\n" + "=" * 60)
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