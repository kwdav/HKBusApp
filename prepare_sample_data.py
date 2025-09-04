#!/usr/bin/env python3
"""
Sample Bus Data Preparation Script - Quick Test Version

This script creates a small sample of bus data for testing purposes
"""

import requests
import json
from datetime import datetime

def create_sample_data():
    print("🚀 Creating sample bus data...")
    
    # Sample data structure
    bus_data = {
        "generated_at": datetime.now().isoformat(),
        "routes": {},
        "stops": {},
        "route_stops": {},
        "stop_routes": {},
        "summary": {}
    }
    
    try:
        # Get a few CTB routes for testing
        print("📡 Fetching sample CTB routes...")
        response = requests.get("https://rt.data.gov.hk/v2/transport/citybus/route/CTB")
        ctb_data = response.json()
        
        # Take first 5 routes only for testing
        sample_routes = ctb_data['data'][:5]
        print(f"📊 Processing {len(sample_routes)} sample routes")
        
        for route_info in sample_routes:
            route_id = route_info['route']
            company = route_info['co']
            
            print(f"  Processing route {company} {route_id}")
            
            # Try both directions
            for direction, dir_code in [('inbound', 'I'), ('outbound', 'O')]:
                stops_url = f"https://rt.data.gov.hk/v2/transport/citybus/route-stop/{company}/{route_id}/{direction}"
                stops_response = requests.get(stops_url)
                
                if stops_response.status_code != 200:
                    continue
                    
                stops_data = stops_response.json()
                if not stops_data.get('data'):
                    continue
                
                unique_route_id = f"{company}_{route_id}_{dir_code}"
                
                # Store route info
                bus_data['routes'][unique_route_id] = {
                    'route_number': route_id,
                    'company': company,
                    'direction': direction,
                    'origin_tc': route_info['orig_tc'],
                    'origin_en': route_info['orig_en'],
                    'dest_tc': route_info['dest_tc'],
                    'dest_en': route_info['dest_en']
                }
                
                # Process stops
                route_stops = []
                for stop_info in stops_data['data']:
                    stop_id = stop_info['stop']
                    seq = stop_info['seq']
                    
                    route_stops.append({
                        'stop_id': stop_id,
                        'sequence': seq
                    })
                    
                    # Get stop details if new
                    if stop_id not in bus_data['stops']:
                        stop_url = f"https://rt.data.gov.hk/v2/transport/citybus/stop/{stop_id}"
                        stop_response = requests.get(stop_url)
                        
                        if stop_response.status_code == 200:
                            stop_detail = stop_response.json()
                            if stop_detail.get('data'):
                                stop_data = stop_detail['data']
                                bus_data['stops'][stop_id] = {
                                    'name_tc': stop_data['name_tc'],
                                    'name_en': stop_data['name_en'],
                                    'latitude': float(stop_data['lat']),
                                    'longitude': float(stop_data['long']),
                                    'company': company
                                }
                
                # Store route stops
                route_stops.sort(key=lambda x: x['sequence'])
                bus_data['route_stops'][unique_route_id] = route_stops
        
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
        with open('sample_bus_data.json', 'w', encoding='utf-8') as f:
            json.dump(bus_data, f, ensure_ascii=False, indent=2)
        
        print("✅ Sample data created successfully!")
        print(f"📊 Summary:")
        print(f"   Routes: {bus_data['summary']['total_routes']}")
        print(f"   Stops: {bus_data['summary']['total_stops']}")
        print(f"   Stop-Route mappings: {bus_data['summary']['total_stop_route_mappings']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error creating sample data: {e}")
        return False

if __name__ == "__main__":
    create_sample_data()