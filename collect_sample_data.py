#!/usr/bin/env python3
"""
收集樣本巴士數據 - 只收集熱門路線以快速測試

目標：收集大約 50-100 條路線的完整數據
"""

import requests
import json
from datetime import datetime
from collections import defaultdict

def fetch_json(url: str, description: str = "") -> dict:
    """Fetch JSON data with error handling"""
    try:
        print(f"📡 {description}...")
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        data = response.json()
        return data
    except Exception as e:
        print(f"❌ Error: {e}")
        return {}

def collect_sample_data():
    """收集樣本數據"""
    print("🚀 Collecting sample Hong Kong bus data...")
    
    # 熱門 KMB 路線
    popular_kmb_routes = [
        "1", "2", "3", "6", "7", "9", "10", "11", "12", "13", "14", "15", "16",
        "28", "35A", "40", "42", "43", "46", "58", "60", "61", "62", "64",
        "70", "72", "73", "74", "75", "80", "81", "85", "86", "87", "88",
        "89", "92", "93", "94", "95", "96", "98", "99", "101", "102", "104", "107", "110"
    ]
    
    bus_data = {
        "generated_at": datetime.now().isoformat(),
        "routes": {},
        "stops": {},
        "route_stops": {},
        "stop_routes": {}
    }
    
    # 1. 獲取所有 KMB 站點（一次性）
    print("📍 Fetching all KMB stops...")
    all_stops_data = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/stop", "All KMB stops")
    
    # 創建站點索引
    stops_index = {}
    if all_stops_data.get('data'):
        for stop in all_stops_data['data']:
            stops_index[stop['stop']] = stop
        print(f"✅ Indexed {len(stops_index)} stops")
    
    # 2. 獲取所有路線資料
    print("🚌 Fetching all KMB routes...")
    all_routes_data = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/route", "All KMB routes")
    
    # 創建路線索引
    routes_index = {}
    if all_routes_data.get('data'):
        for route in all_routes_data['data']:
            key = f"{route['route']}_{route['bound']}_{route['service_type']}"
            routes_index[key] = route
        print(f"✅ Indexed {len(routes_index)} route variations")
    
    # 3. 獲取所有路線站點映射
    print("🗺️ Fetching all route-stop mappings...")
    all_route_stops_data = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/route-stop", "All route-stops")
    
    # 4. 只處理熱門路線
    print("🎯 Processing popular routes...")
    
    route_stops_grouped = defaultdict(list)
    used_stops = set()
    processed_routes = 0
    
    if all_route_stops_data.get('data'):
        for route_stop in all_route_stops_data['data']:
            route_num = route_stop['route']
            
            # 只處理熱門路線
            if route_num not in popular_kmb_routes:
                continue
            
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
    
    print(f"✅ Processed {processed_routes} routes")
    print(f"✅ Found {len(used_stops)} unique stops")
    
    # 5. 只添加使用的站點資料
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
    
    # 7. 創建反向映射
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
    
    # 8. 添加統計
    bus_data['summary'] = {
        'total_routes': len(bus_data['routes']),
        'total_stops': len(bus_data['stops']),
        'total_stop_route_mappings': len(bus_data['stop_routes'])
    }
    
    print(f"📊 Final Summary:")
    print(f"   Routes: {bus_data['summary']['total_routes']}")
    print(f"   Stops: {bus_data['summary']['total_stops']}")
    print(f"   Stop-Route Mappings: {bus_data['summary']['total_stop_route_mappings']}")
    
    # 9. 保存數據
    filename = "sample_bus_data_optimized.json"
    print(f"💾 Saving to {filename}...")
    
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(bus_data, f, ensure_ascii=False, indent=2)
    
    import os
    file_size = os.path.getsize(filename)
    print(f"✅ Saved! File size: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")
    
    return bus_data

if __name__ == "__main__":
    collect_sample_data()
    print("🎉 Sample data collection completed!")