#!/usr/bin/env python3
"""
HK Bus Data Preparation Script

This script fetches all bus routes and stops from Hong Kong government APIs
and creates a comprehensive JSON file for the iOS app to use.

Data Sources:
- CTB/NWFB: https://rt.data.gov.hk/v2/transport/citybus/
- KMB: https://data.etabus.gov.hk/v1/transport/kmb/

Output: bus_data.json with complete route and stop information
"""

import requests
import json
import time
from typing import Dict, List, Any
from datetime import datetime

class BusDataCollector:
    def __init__(self):
        self.ctb_base = "https://rt.data.gov.hk/v2/transport/citybus"
        self.kmb_base = "https://data.etabus.gov.hk/v1/transport/kmb"
        
        # Final data structure
        self.bus_data = {
            "generated_at": datetime.now().isoformat(),
            "routes": {},  # routeId -> route info
            "stops": {},   # stopId -> stop info  
            "route_stops": {}  # routeId -> [stops in order]
        }
        
    def fetch_json(self, url: str, company: str) -> Dict[str, Any]:
        """Fetch JSON data with error handling"""
        try:
            print(f"📡 Fetching {company}: {url}")
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"❌ Error fetching {url}: {e}")
            return {}
    
    def collect_ctb_data(self):
        """Collect CTB and NWFB route and stop data"""
        print("🚌 Collecting CTB/NWFB data...")
        
        # Get all CTB routes
        ctb_routes = self.fetch_json(f"{self.ctb_base}/route/CTB", "CTB Routes")
        nwfb_routes = self.fetch_json(f"{self.ctb_base}/route/NWFB", "NWFB Routes")
        
        all_ctb_routes = ctb_routes.get('data', []) + nwfb_routes.get('data', [])
        print(f"📊 Found {len(all_ctb_routes)} CTB/NWFB routes")
        
        for i, route_info in enumerate(all_ctb_routes):
            if i % 50 == 0:  # Progress indicator
                print(f"  Processing route {i+1}/{len(all_ctb_routes)}")
            
            route_id = route_info['route']
            company = route_info['co']  # Changed from 'company' to 'co'
            
            # For CTB/NWFB, we need to try both directions (inbound and outbound)
            for direction, dir_code in [('inbound', 'I'), ('outbound', 'O')]:
                # Get stops for this route direction
                stops_data = self.fetch_json(
                    f"{self.ctb_base}/route-stop/{company}/{route_id}/{direction}", 
                    f"{company} {route_id} {direction} stops"
                )
                
                if not stops_data.get('data'):
                    continue  # Skip if no stops found for this direction
                
                unique_route_id = f"{company}_{route_id}_{dir_code}"
                
                # Store route basic info
                self.bus_data['routes'][unique_route_id] = {
                    'route_number': route_id,
                    'company': company,
                    'direction': direction,
                    'origin_tc': route_info['orig_tc'],
                    'origin_en': route_info['orig_en'],
                    'dest_tc': route_info['dest_tc'],
                    'dest_en': route_info['dest_en']
                }
                
                route_stops = []
                for stop_info in stops_data.get('data', []):
                    stop_id = stop_info['stop']
                    seq = stop_info['seq']
                    
                    # Add to route stops
                    route_stops.append({
                        'stop_id': stop_id,
                        'sequence': seq
                    })
                    
                    # Get stop details if we don't have it yet
                    if stop_id not in self.bus_data['stops']:
                        stop_detail = self.fetch_json(
                            f"{self.ctb_base}/stop/{stop_id}",
                            f"Stop {stop_id}"
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
                
                # Sort stops by sequence
                route_stops.sort(key=lambda x: x['sequence'])
                self.bus_data['route_stops'][unique_route_id] = route_stops
                
                time.sleep(0.05)  # Be nice to the API
            
            time.sleep(0.1)  # Extra pause between routes
    
    def collect_kmb_data(self):
        """Collect KMB route and stop data"""
        print("🚌 Collecting KMB data...")
        
        # Get all KMB routes
        routes_data = self.fetch_json(f"{self.kmb_base}/route", "KMB Routes")
        routes = routes_data.get('data', [])
        print(f"📊 Found {len(routes)} KMB routes")
        
        for i, route_info in enumerate(routes):
            if i % 50 == 0:  # Progress indicator
                print(f"  Processing route {i+1}/{len(routes)}")
            
            route_id = route_info['route']
            direction = route_info['bound']  # I (inbound) or O (outbound) 
            service_type = route_info['service_type']
            
            unique_route_id = f"KMB_{route_id}_{direction}_{service_type}"
            
            # Store route basic info
            self.bus_data['routes'][unique_route_id] = {
                'route_number': route_id,
                'company': 'KMB',
                'direction': 'inbound' if direction == 'I' else 'outbound',
                'origin_tc': route_info['orig_tc'],
                'origin_en': route_info['orig_en'],
                'dest_tc': route_info['dest_tc'],
                'dest_en': route_info['dest_en'],
                'service_type': service_type
            }
            
            # Get stops for this route
            stops_data = self.fetch_json(
                f"{self.kmb_base}/route-stop/{route_id}/{direction}/{service_type}",
                f"KMB {route_id} stops"
            )
            
            route_stops = []
            for stop_info in stops_data.get('data', []):
                stop_id = stop_info['stop']
                seq = stop_info['seq']
                
                # Add to route stops
                route_stops.append({
                    'stop_id': stop_id,
                    'sequence': seq
                })
                
                # Get stop details if we don't have it yet
                if stop_id not in self.bus_data['stops']:
                    stop_detail = self.fetch_json(
                        f"{self.kmb_base}/stop/{stop_id}",
                        f"KMB Stop {stop_id}"
                    )
                    
                    if stop_detail.get('data'):
                        stop_data = stop_detail['data']
                        self.bus_data['stops'][stop_id] = {
                            'name_tc': stop_data['name_tc'],
                            'name_en': stop_data['name_en'],
                            'latitude': float(stop_data['lat']),
                            'longitude': float(stop_data['long']),
                            'company': 'KMB'
                        }
            
            # Sort stops by sequence
            route_stops.sort(key=lambda x: x['sequence'])
            self.bus_data['route_stops'][unique_route_id] = route_stops
            
            time.sleep(0.1)  # Be nice to the API
    
    def create_stop_to_routes_mapping(self):
        """Create reverse mapping: stop -> routes that pass through it"""
        print("🔄 Creating stop-to-routes mapping...")
        
        stop_routes = {}
        
        for route_id, stops in self.bus_data['route_stops'].items():
            route_info = self.bus_data['routes'][route_id]
            
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
        
        # Add to main data
        self.bus_data['stop_routes'] = stop_routes
        
        print(f"📊 Created mappings for {len(stop_routes)} stops")
    
    def save_data(self, filename: str):
        """Save collected data to JSON file"""
        print(f"💾 Saving data to {filename}")
        
        # Add summary statistics
        self.bus_data['summary'] = {
            'total_routes': len(self.bus_data['routes']),
            'total_stops': len(self.bus_data['stops']),
            'total_stop_route_mappings': len(self.bus_data.get('stop_routes', {}))
        }
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(self.bus_data, f, ensure_ascii=False, indent=2)
        
        print("✅ Data saved successfully!")
        print(f"📊 Summary:")
        print(f"   Routes: {self.bus_data['summary']['total_routes']}")
        print(f"   Stops: {self.bus_data['summary']['total_stops']}")
        print(f"   Stop-Route mappings: {self.bus_data['summary']['total_stop_route_mappings']}")

def main():
    collector = BusDataCollector()
    
    print("🚀 Starting Hong Kong Bus Data Collection")
    print("=" * 50)
    
    try:
        # Collect data from all sources
        collector.collect_ctb_data()
        collector.collect_kmb_data()
        
        # Create reverse mappings
        collector.create_stop_to_routes_mapping()
        
        # Save to file
        collector.save_data('bus_data.json')
        
        print("=" * 50)
        print("🎉 Bus data collection completed successfully!")
        
    except KeyboardInterrupt:
        print("\n❌ Collection interrupted by user")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()