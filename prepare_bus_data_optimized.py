#!/usr/bin/env python3
"""
優化版的香港巴士數據收集腳本

關鍵優化：
1. 批量獲取所有 KMB 站點資料（一次 API 調用）
2. 批量獲取所有路線站點映射（一次 API 調用）
3. 減少不必要的重複請求

API 端點：
- KMB 所有站點: https://data.etabus.gov.hk/v1/transport/kmb/stop
- KMB 所有路線站點: https://data.etabus.gov.hk/v1/transport/kmb/route-stop
- CTB/NWFB: https://rt.data.gov.hk/v2/transport/citybus/
"""

import requests
import json
import time
from typing import Dict, List, Any
from datetime import datetime
from collections import defaultdict

class OptimizedBusDataCollector:
    def __init__(self):
        self.ctb_base = "https://rt.data.gov.hk/v2/transport/citybus"
        self.kmb_base = "https://data.etabus.gov.hk/v1/transport/kmb"
        
        # Final data structure
        self.bus_data = {
            "generated_at": datetime.now().isoformat(),
            "routes": {},  # routeId -> route info
            "stops": {},   # stopId -> stop info  
            "route_stops": {},  # routeId -> [stops in order]
            "stop_routes": {}  # stopId -> [routes passing through]
        }
        
    def fetch_json(self, url: str, description: str = "") -> Dict[str, Any]:
        """Fetch JSON data with error handling"""
        try:
            print(f"📡 Fetching {description}: {url}")
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            data = response.json()
            if 'data' in data:
                print(f"✅ Got {len(data['data'])} records")
            return data
        except Exception as e:
            print(f"❌ Error fetching {description}: {e}")
            return {}
    
    def collect_kmb_data_optimized(self):
        """優化的 KMB 數據收集 - 批量獲取所有資料"""
        print("🚌 Collecting KMB data (optimized)...")
        
        # 1. 批量獲取所有 KMB 站點 (一次 API 調用！)
        print("📍 Fetching ALL KMB stops in one call...")
        all_stops = self.fetch_json(f"{self.kmb_base}/stop", "All KMB stops")
        
        if not all_stops.get('data'):
            print("❌ Failed to get KMB stops data")
            return
            
        # 處理所有站點資料
        for stop_data in all_stops['data']:
            stop_id = stop_data['stop']
            self.bus_data['stops'][stop_id] = {
                'name_tc': stop_data['name_tc'],
                'name_en': stop_data['name_en'], 
                'latitude': float(stop_data['lat']),
                'longitude': float(stop_data['long']),
                'company': 'KMB'
            }
        
        print(f"✅ Processed {len(self.bus_data['stops'])} KMB stops")
        
        # 2. 批量獲取所有路線站點映射 (一次 API 調用！)
        print("🗺️ Fetching ALL KMB route-stops in one call...")
        all_route_stops = self.fetch_json(f"{self.kmb_base}/route-stop", "All KMB route-stops")
        
        if not all_route_stops.get('data'):
            print("❌ Failed to get KMB route-stops data")
            return
            
        # 3. 批量獲取所有路線資料
        print("🚌 Fetching ALL KMB routes...")
        all_routes = self.fetch_json(f"{self.kmb_base}/route", "All KMB routes")
        
        if not all_routes.get('data'):
            print("❌ Failed to get KMB routes data")
            return
        
        # 創建路線資料索引
        routes_index = {}
        for route_data in all_routes['data']:
            route_key = f"{route_data['route']}_{route_data['bound']}_{route_data['service_type']}"
            routes_index[route_key] = route_data
        
        # 處理路線站點映射
        route_stops_grouped = defaultdict(list)
        
        for route_stop in all_route_stops['data']:
            route = route_stop['route']
            bound = route_stop['bound']
            service_type = route_stop['service_type']
            stop_id = route_stop['stop']
            seq = route_stop['seq']
            
            route_key = f"{route}_{bound}_{service_type}"
            unique_route_id = f"KMB_{route}_{bound}"
            
            # 添加到分組
            route_stops_grouped[unique_route_id].append({
                'stop_id': stop_id,
                'sequence': seq
            })
            
            # 創建路線資料
            if unique_route_id not in self.bus_data['routes'] and route_key in routes_index:
                route_info = routes_index[route_key]
                self.bus_data['routes'][unique_route_id] = {
                    'route_number': route,
                    'company': 'KMB',
                    'direction': 'inbound' if bound == 'I' else 'outbound',
                    'origin_tc': route_info['orig_tc'],
                    'origin_en': route_info['orig_en'],
                    'dest_tc': route_info['dest_tc'],
                    'dest_en': route_info['dest_en'],
                    'service_type': service_type
                }
        
        # 排序並儲存路線站點
        for route_id, stops in route_stops_grouped.items():
            stops.sort(key=lambda x: x['sequence'])
            self.bus_data['route_stops'][route_id] = stops
        
        print(f"✅ Processed {len(self.bus_data['routes'])} KMB routes")
        print(f"✅ Processed {len(route_stops_grouped)} route-stop mappings")
    
    def collect_ctb_data(self):
        """收集 CTB/NWFB 數據"""
        print("🚌 Collecting CTB/NWFB data...")
        
        companies = ['CTB', 'NWFB']
        
        for company in companies:
            print(f"📋 Processing {company} routes...")
            
            # Get all routes for this company
            routes_data = self.fetch_json(f"{self.ctb_base}/route/{company}", f"{company} routes")
            
            if not routes_data.get('data'):
                print(f"❌ No {company} routes found")
                continue
            
            route_count = 0
            for route_info in routes_data['data']:
                route_id = route_info['route']
                
                # Process both directions
                for direction, dir_code in [('inbound', 'I'), ('outbound', 'O')]:
                    unique_route_id = f"{company}_{route_id}_{dir_code}"
                    
                    # Add route info
                    self.bus_data['routes'][unique_route_id] = {
                        'route_number': route_id,
                        'company': company,
                        'direction': direction,
                        'origin_tc': route_info['orig_tc'],
                        'origin_en': route_info['orig_en'],
                        'dest_tc': route_info['dest_tc'],
                        'dest_en': route_info['dest_en']
                    }
                    
                    # Get stops for this route direction
                    stops_data = self.fetch_json(
                        f"{self.ctb_base}/route-stop/{company}/{route_id}/{direction}", 
                        f"{company} {route_id} {direction} stops"
                    )
                    
                    if not stops_data.get('data'):
                        continue
                    
                    route_stops = []
                    for stop_info in stops_data['data']:
                        stop_id = stop_info['stop']
                        seq = stop_info['seq']
                        
                        route_stops.append({
                            'stop_id': stop_id,
                            'sequence': seq
                        })
                        
                        # Get stop details if we don't have it
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
                    
                    # Sort and store route stops
                    route_stops.sort(key=lambda x: x['sequence'])
                    self.bus_data['route_stops'][unique_route_id] = route_stops
                    route_count += 1
                    
                    # Small delay to be nice to API
                    time.sleep(0.05)
            
            print(f"✅ Processed {route_count} {company} route directions")
    
    def create_stop_routes_mapping(self):
        """創建站點到路線的反向映射"""
        print("🔄 Creating stop-to-routes mapping...")
        
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
    
    def add_summary(self):
        """添加統計摘要"""
        self.bus_data['summary'] = {
            'total_routes': len(self.bus_data['routes']),
            'total_stops': len(self.bus_data['stops']),
            'total_stop_route_mappings': len(self.bus_data['stop_routes'])
        }
        
        print(f"📊 Summary:")
        print(f"   Routes: {self.bus_data['summary']['total_routes']}")
        print(f"   Stops: {self.bus_data['summary']['total_stops']}")
        print(f"   Stop-Route Mappings: {self.bus_data['summary']['total_stop_route_mappings']}")
    
    def save_data(self, filename: str = "bus_data.json"):
        """保存數據到文件"""
        print(f"💾 Saving data to {filename}...")
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(self.bus_data, f, ensure_ascii=False, indent=2)
        
        print(f"✅ Data saved to {filename}")
        
        # Print file size
        import os
        file_size = os.path.getsize(filename)
        print(f"📁 File size: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")

def main():
    print("🚀 Starting optimized HK Bus data collection...")
    print("=" * 60)
    
    collector = OptimizedBusDataCollector()
    
    try:
        # 1. 收集 KMB 數據 (批量，超快！)
        collector.collect_kmb_data_optimized()
        print()
        
        # 2. 收集 CTB/NWFB 數據
        collector.collect_ctb_data()
        print()
        
        # 3. 創建反向映射
        collector.create_stop_routes_mapping()
        print()
        
        # 4. 添加統計
        collector.add_summary()
        print()
        
        # 5. 保存數據
        collector.save_data()
        
        print("=" * 60)
        print("🎉 Data collection completed successfully!")
        
    except KeyboardInterrupt:
        print("\n⏸️ Collection interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        raise

if __name__ == "__main__":
    main()