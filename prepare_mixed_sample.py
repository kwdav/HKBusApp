#!/usr/bin/env python3
"""
Mixed Sample Bus Data - CTB + KMB
包含更多樣化的站點測試數據
"""

import requests
import json
from datetime import datetime

def create_mixed_sample():
    print("🚀 Creating mixed sample bus data (CTB + KMB)...")
    
    bus_data = {
        "generated_at": datetime.now().isoformat(),
        "routes": {},
        "stops": {},
        "route_stops": {},
        "stop_routes": {},
        "summary": {}
    }
    
    try:
        # Get CTB route 1 (中環-跑馬地)
        print("📡 Adding CTB Route 1...")
        ctb_routes = requests.get("https://rt.data.gov.hk/v2/transport/citybus/route/CTB").json()
        route_1 = ctb_routes['data'][0]  # Route 1
        
        for direction, dir_code in [('inbound', 'I'), ('outbound', 'O')]:
            stops_response = requests.get(f"https://rt.data.gov.hk/v2/transport/citybus/route-stop/CTB/1/{direction}")
            if stops_response.status_code == 200:
                stops_data = stops_response.json()
                unique_route_id = f"CTB_1_{dir_code}"
                
                bus_data['routes'][unique_route_id] = {
                    'route_number': '1',
                    'company': 'CTB',
                    'direction': direction,
                    'origin_tc': route_1['orig_tc'],
                    'origin_en': route_1['orig_en'],
                    'dest_tc': route_1['dest_tc'],
                    'dest_en': route_1['dest_en']
                }
                
                route_stops = []
                for stop_info in stops_data['data'][:8]:  # First 8 stops only
                    stop_id = stop_info['stop']
                    route_stops.append({'stop_id': stop_id, 'sequence': stop_info['seq']})
                    
                    # Get stop details
                    if stop_id not in bus_data['stops']:
                        stop_response = requests.get(f"https://rt.data.gov.hk/v2/transport/citybus/stop/{stop_id}")
                        if stop_response.status_code == 200:
                            stop_detail = stop_response.json()['data']
                            bus_data['stops'][stop_id] = {
                                'name_tc': stop_detail['name_tc'],
                                'name_en': stop_detail['name_en'],
                                'latitude': float(stop_detail['lat']),
                                'longitude': float(stop_detail['long']),
                                'company': 'CTB'
                            }
                
                bus_data['route_stops'][unique_route_id] = route_stops
        
        # Get some popular KMB routes
        print("📡 Adding KMB Routes...")
        kmb_routes = requests.get("https://data.etabus.gov.hk/v1/transport/kmb/route").json()
        
        # Find some popular routes like 1A, 6, 9
        popular_kmb = ['1A', '6', '9', '271']
        for route_data in kmb_routes['data']:
            if route_data['route'] in popular_kmb and route_data['service_type'] == '1':
                route_id = route_data['route']
                direction = route_data['bound']  # I or O
                service_type = route_data['service_type']
                
                print(f"  Processing KMB {route_id} direction {direction}")
                
                # Get route stops
                stops_response = requests.get(
                    f"https://data.etabus.gov.hk/v1/transport/kmb/route-stop/{route_id}/{direction}/{service_type}"
                )
                
                if stops_response.status_code == 200:
                    stops_data = stops_response.json()
                    unique_route_id = f"KMB_{route_id}_{direction}_{service_type}"
                    
                    bus_data['routes'][unique_route_id] = {
                        'route_number': route_id,
                        'company': 'KMB',
                        'direction': 'inbound' if direction == 'I' else 'outbound',
                        'origin_tc': route_data['orig_tc'],
                        'origin_en': route_data['orig_en'],
                        'dest_tc': route_data['dest_tc'],
                        'dest_en': route_data['dest_en'],
                        'service_type': service_type
                    }
                    
                    route_stops = []
                    for stop_info in stops_data['data'][:10]:  # First 10 stops
                        stop_id = stop_info['stop']
                        route_stops.append({'stop_id': stop_id, 'sequence': stop_info['seq']})
                        
                        # Get stop details
                        if stop_id not in bus_data['stops']:
                            stop_response = requests.get(f"https://data.etabus.gov.hk/v1/transport/kmb/stop/{stop_id}")
                            if stop_response.status_code == 200:
                                stop_detail = stop_response.json()['data']
                                bus_data['stops'][stop_id] = {
                                    'name_tc': stop_detail['name_tc'],
                                    'name_en': stop_detail['name_en'],
                                    'latitude': float(stop_detail['lat']),
                                    'longitude': float(stop_detail['long']),
                                    'company': 'KMB'
                                }
                    
                    bus_data['route_stops'][unique_route_id] = route_stops
                
                # Limit to avoid too many requests
                if len(bus_data['routes']) >= 12:
                    break
        
        # Create stop-to-routes mapping
        stop_routes = {}
        for route_id, stops in bus_data['route_stops'].items():
            route_info = bus_data['routes'][route_id]
            
            for stop in stops:
                stop_id = stop['stop_id']
                if stop_id not in stop_routes:
                    stop_routes[stop_id] = []
                
                stop_routes[stop_id].append({
                    'route_number': route_info['route_number'],
                    'company': route_info['company'],
                    'direction': route_info['direction'],
                    'destination': route_info['dest_tc'],
                    'sequence': stop['sequence'],
                    'route_id': route_id
                })
        
        bus_data['stop_routes'] = stop_routes
        
        # Add summary
        bus_data['summary'] = {
            'total_routes': len(bus_data['routes']),
            'total_stops': len(bus_data['stops']),
            'total_stop_route_mappings': len(stop_routes)
        }
        
        # Save to file
        with open('mixed_sample_data.json', 'w', encoding='utf-8') as f:
            json.dump(bus_data, f, ensure_ascii=False, indent=2)
        
        print("✅ Mixed sample data created successfully!")
        print(f"📊 Summary:")
        print(f"   Routes: {bus_data['summary']['total_routes']}")
        print(f"   Stops: {bus_data['summary']['total_stops']}")
        print(f"   Stop-Route mappings: {bus_data['summary']['total_stop_route_mappings']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error creating mixed sample data: {e}")
        return False

if __name__ == "__main__":
    create_mixed_sample()