#!/usr/bin/env python3
"""
收集完整香港巴士數據 - KMB + CTB 所有路線和站點

不做任何過濾，收集所有可用的路線，讓用戶自己選擇需要的路線
"""

import requests
import json
from datetime import datetime
from collections import defaultdict
import time

def fetch_json(url: str, description: str = "") -> dict:
    """Fetch JSON data with error handling"""
    try:
        print(f"📡 {description}...")
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        data = response.json()
        if 'data' in data:
            print(f"✅ Got {len(data['data'])} records")
        return data
    except Exception as e:
        print(f"❌ Error: {e}")
        return {}

def collect_complete_kmb_data(bus_data):
    """收集所有 KMB 數據"""
    print("🚌 Collecting ALL KMB data...")
    
    # 1. 獲取所有 KMB 站點（一次性）
    print("📍 Fetching ALL KMB stops...")
    all_stops_data = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/stop", "All KMB stops")
    
    # 創建站點索引
    stops_index = {}
    if all_stops_data.get('data'):
        for stop in all_stops_data['data']:
            stops_index[stop['stop']] = stop
        print(f"✅ Indexed {len(stops_index)} KMB stops")
    
    # 2. 獲取所有路線資料
    print("🚌 Fetching ALL KMB routes...")
    all_routes_data = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/route", "All KMB routes")
    
    # 創建路線索引
    routes_index = {}
    if all_routes_data.get('data'):
        for route in all_routes_data['data']:
            key = f"{route['route']}_{route['bound']}_{route['service_type']}"
            routes_index[key] = route
        print(f"✅ Indexed {len(routes_index)} KMB route variations")
    
    # 3. 獲取所有路線站點映射
    print("🗺️ Fetching ALL KMB route-stop mappings...")
    all_route_stops_data = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/route-stop", "All KMB route-stops")
    
    # 4. 處理所有路線（不過濾！）
    print("🎯 Processing ALL KMB routes...")
    
    route_stops_grouped = defaultdict(list)
    used_stops = set()
    processed_routes = 0
    
    if all_route_stops_data.get('data'):
        for route_stop in all_route_stops_data['data']:
            route_num = route_stop['route']
            bound = route_stop['bound'] 
            service_type = route_stop['service_type']
            stop_id = route_stop['stop']
            seq = route_stop['seq']
            
            route_key = f"{route_num}_{bound}_{service_type}"
            unique_route_id = f"KMB_{route_num}_{bound}"
            
            # 添加到路線站點分組
            route_stops_grouped[unique_route_id].append({
                'stop_id': stop_id,
                'sequence': seq
            })
            
            # 記錄使用的站點
            used_stops.add(stop_id)
            
            # 創建路線資料
            if unique_route_id not in bus_data['routes'] and route_key in routes_index:
                route_info = routes_index[route_key]
                bus_data['routes'][unique_route_id] = {
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
    
    print(f"✅ Processed {processed_routes} KMB routes")
    print(f"✅ Found {len(used_stops)} unique KMB stops")
    
    # 5. 添加所有使用的站點資料
    for stop_id in used_stops:
        if stop_id in stops_index:
            stop_data = stops_index[stop_id]
            bus_data['stops'][stop_id] = {
                'name_tc': stop_data['name_tc'],
                'name_en': stop_data['name_en'],
                'latitude': float(stop_data['lat']),
                'longitude': float(stop_data['long']),
                'company': 'KMB'
            }
    
    # 6. 整理路線站點並排序
    for route_id, stops in route_stops_grouped.items():
        stops.sort(key=lambda x: x['sequence'])
        bus_data['route_stops'][route_id] = stops
    
    print(f"✅ Added {len(bus_data['stops'])} KMB stops to dataset")

def collect_complete_ctb_data(bus_data):
    """收集所有 CTB/NWFB 數據"""
    print("🚌 Collecting ALL CTB/NWFB data...")
    
    companies = ['CTB', 'NWFB']
    
    for company in companies:
        print(f"📋 Processing ALL {company} routes...")
        
        # Get all routes for this company
        routes_data = fetch_json(f"https://rt.data.gov.hk/v2/transport/citybus/route/{company}", f"All {company} routes")
        
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
                bus_data['routes'][unique_route_id] = {
                    'route_number': route_id,
                    'company': company,
                    'direction': direction,
                    'origin_tc': route_info['orig_tc'],
                    'origin_en': route_info['orig_en'],
                    'dest_tc': route_info['dest_tc'],
                    'dest_en': route_info['dest_en']
                }
                
                # Get stops for this route direction
                stops_data = fetch_json(
                    f"https://rt.data.gov.hk/v2/transport/citybus/route-stop/{company}/{route_id}/{direction}", 
                    f"{company} {route_id} {direction} stops"
                )
                
                if not stops_data.get('data'):
                    print(f"⚠️ No stops found for {company} {route_id} {direction}")
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
                    if stop_id not in bus_data['stops']:
                        stop_detail = fetch_json(
                            f"https://rt.data.gov.hk/v2/transport/citybus/stop/{stop_id}", 
                            f"{company} stop {stop_id}"
                        )
                        
                        if stop_detail.get('data'):
                            stop_data = stop_detail['data']
                            bus_data['stops'][stop_id] = {
                                'name_tc': stop_data['name_tc'],
                                'name_en': stop_data['name_en'],
                                'latitude': float(stop_data['lat']),
                                'longitude': float(stop_data['long']),
                                'company': company
                            }
                        
                        # Small delay to be nice to API
                        time.sleep(0.05)
                
                # Sort and store route stops
                route_stops.sort(key=lambda x: x['sequence'])
                bus_data['route_stops'][unique_route_id] = route_stops
                route_count += 1
                
                # Small delay between route directions
                time.sleep(0.02)
        
        print(f"✅ Processed {route_count} {company} route directions")

def create_stop_routes_mapping(bus_data):
    """創建站點到路線的反向映射"""
    print("🔄 Creating stop-to-routes mapping...")
    
    for route_id, stops in bus_data['route_stops'].items():
        route_info = bus_data['routes'][route_id]
        
        for stop_info in stops:
            stop_id = stop_info['stop_id']
            
            if stop_id not in bus_data['stop_routes']:
                bus_data['stop_routes'][stop_id] = []
            
            bus_data['stop_routes'][stop_id].append({
                'route_number': route_info['route_number'],
                'company': route_info['company'],
                'direction': route_info['direction'],
                'destination': route_info['dest_tc'],
                'sequence': stop_info['sequence'],
                'route_id': route_id
            })

def collect_complete_data():
    """收集完整數據"""
    print("🚀 Collecting COMPLETE Hong Kong bus data...")
    print("📝 Target: ALL KMB + CTB/NWFB routes and stops")
    print("=" * 60)
    
    bus_data = {
        "generated_at": datetime.now().isoformat(),
        "routes": {},
        "stops": {},
        "route_stops": {},
        "stop_routes": {}
    }
    
    try:
        # 1. 收集所有 KMB 數據
        collect_complete_kmb_data(bus_data)
        print()
        
        # 2. 收集所有 CTB/NWFB 數據
        collect_complete_ctb_data(bus_data)
        print()
        
        # 3. 創建反向映射
        create_stop_routes_mapping(bus_data)
        print()
        
        # 4. 添加統計
        bus_data['summary'] = {
            'total_routes': len(bus_data['routes']),
            'total_stops': len(bus_data['stops']),
            'total_stop_route_mappings': len(bus_data['stop_routes'])
        }
        
        print(f"📊 COMPLETE Dataset Summary:")
        print(f"   Total Routes: {bus_data['summary']['total_routes']}")
        print(f"   Total Stops: {bus_data['summary']['total_stops']}")
        print(f"   Stop-Route Mappings: {bus_data['summary']['total_stop_route_mappings']}")
        print()
        
        # 5. 保存數據
        filename = "bus_data_complete.json"
        print(f"💾 Saving complete dataset to {filename}...")
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(bus_data, f, ensure_ascii=False, indent=2)
        
        import os
        file_size = os.path.getsize(filename)
        print(f"✅ Saved! File size: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")
        
        print("=" * 60)
        print("🎉 COMPLETE data collection finished successfully!")
        print("📱 All KMB + CTB/NWFB routes and stops included!")
        
        return bus_data
        
    except KeyboardInterrupt:
        print("\n⏸️ Collection interrupted by user")
        return None
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        raise

if __name__ == "__main__":
    collect_complete_data()