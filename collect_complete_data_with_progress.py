#!/usr/bin/env python3
"""
收集完整香港巴士數據 - 帶進度顯示版本
"""

import requests
import json
from datetime import datetime
from collections import defaultdict
import time

def fetch_json(url: str, description: str = "") -> dict:
    """Fetch JSON data with error handling and progress"""
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        data = response.json()
        return data
    except Exception as e:
        print(f"❌ Error fetching {description}: {e}")
        return {}

def collect_complete_data():
    """收集完整數據 - 帶詳細進度"""
    print("🚀 Starting COMPLETE Hong Kong bus data collection...")
    print("=" * 60)
    
    bus_data = {
        "generated_at": datetime.now().isoformat(),
        "routes": {},
        "stops": {},
        "route_stops": {},
        "stop_routes": {}
    }
    
    # === KMB 數據收集 ===
    print("📍 Step 1/6: Collecting KMB stops...")
    all_stops = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/stop", "KMB stops")
    
    stops_index = {}
    if all_stops.get('data'):
        for stop in all_stops['data']:
            stops_index[stop['stop']] = stop
        print(f"✅ Indexed {len(stops_index)} KMB stops")
    
    print("🚌 Step 2/6: Collecting KMB routes...")
    all_routes = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/route", "KMB routes")
    
    routes_index = {}
    if all_routes.get('data'):
        for route in all_routes['data']:
            key = f"{route['route']}_{route['bound']}_{route['service_type']}"
            routes_index[key] = route
        print(f"✅ Indexed {len(routes_index)} KMB route variations")
    
    print("🗺️ Step 3/6: Collecting KMB route-stops...")
    all_route_stops = fetch_json("https://data.etabus.gov.hk/v1/transport/kmb/route-stop", "KMB route-stops")
    
    # 處理 KMB 數據
    route_stops_grouped = defaultdict(list)
    used_stops = set()
    
    if all_route_stops.get('data'):
        total_records = len(all_route_stops['data'])
        print(f"📊 Processing {total_records:,} KMB route-stop records...")
        
        for i, route_stop in enumerate(all_route_stops['data']):
            if i % 5000 == 0:
                print(f"   Progress: {i:,}/{total_records:,} ({i/total_records*100:.1f}%)")
                
            route_num = route_stop['route']
            bound = route_stop['bound']
            service_type = route_stop['service_type']
            stop_id = route_stop['stop']
            seq = route_stop['seq']
            
            route_key = f"{route_num}_{bound}_{service_type}"
            unique_route_id = f"KMB_{route_num}_{bound}"
            
            route_stops_grouped[unique_route_id].append({
                'stop_id': stop_id,
                'sequence': seq
            })
            
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
    
    # 添加 KMB 站點
    print("📍 Adding KMB stop data...")
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
    
    # 整理 KMB 路線站點
    for route_id, stops in route_stops_grouped.items():
        stops.sort(key=lambda x: x['sequence'])
        bus_data['route_stops'][route_id] = stops
    
    print(f"✅ KMB Summary: {len(bus_data['routes'])} routes, {len(used_stops)} stops")
    
    # === CTB/NWFB 數據收集 ===
    companies = ['CTB', 'NWFB']
    
    for company in companies:
        print(f"🚌 Step 4/6: Collecting {company} data...")
        
        # 獲取所有路線
        routes_data = fetch_json(f"https://rt.data.gov.hk/v2/transport/citybus/route/{company}", f"{company} routes")
        
        if not routes_data.get('data'):
            print(f"❌ No {company} routes found")
            continue
        
        total_routes = len(routes_data['data'])
        print(f"📊 Processing {total_routes} {company} routes...")
        
        route_count = 0
        for i, route_info in enumerate(routes_data['data']):
            if i % 20 == 0:
                print(f"   Progress: {i}/{total_routes} routes ({i/total_routes*100:.1f}%)")
            
            route_id = route_info['route']
            
            # 處理兩個方向
            for direction, dir_code in [('inbound', 'I'), ('outbound', 'O')]:
                unique_route_id = f"{company}_{route_id}_{dir_code}"
                
                # 添加路線資料
                bus_data['routes'][unique_route_id] = {
                    'route_number': route_id,
                    'company': company,
                    'direction': direction,
                    'origin_tc': route_info['orig_tc'],
                    'origin_en': route_info['orig_en'],
                    'dest_tc': route_info['dest_tc'],
                    'dest_en': route_info['dest_en']
                }
                
                # 獲取站點
                stops_data = fetch_json(
                    f"https://rt.data.gov.hk/v2/transport/citybus/route-stop/{company}/{route_id}/{direction}",
                    f"{company} {route_id} {direction}"
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
                    
                    # 獲取站點詳情
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
                
                route_stops.sort(key=lambda x: x['sequence'])
                bus_data['route_stops'][unique_route_id] = route_stops
                route_count += 1
                
                # 小延遲
                time.sleep(0.01)
        
        print(f"✅ {company} Summary: {route_count} route directions processed")
    
    # === 創建反向映射 ===
    print("🔄 Step 5/6: Creating stop-to-routes mapping...")
    
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
    
    # === 完成統計 ===
    bus_data['summary'] = {
        'total_routes': len(bus_data['routes']),
        'total_stops': len(bus_data['stops']),
        'total_stop_route_mappings': len(bus_data['stop_routes'])
    }
    
    print("📊 Step 6/6: Final statistics...")
    print(f"   Total Routes: {bus_data['summary']['total_routes']:,}")
    print(f"   Total Stops: {bus_data['summary']['total_stops']:,}")
    print(f"   Stop-Route Mappings: {bus_data['summary']['total_stop_route_mappings']:,}")
    
    # === 保存檔案 ===
    filename = "bus_data_complete.json"
    print(f"💾 Saving to {filename}...")
    
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(bus_data, f, ensure_ascii=False, indent=2)
    
    import os
    file_size = os.path.getsize(filename)
    print(f"✅ File saved: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")
    
    print("=" * 60)
    print("🎉 COMPLETE dataset collection finished!")
    
    return bus_data

if __name__ == "__main__":
    collect_complete_data()