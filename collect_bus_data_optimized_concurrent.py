#!/usr/bin/env python3
"""
終極優化版香港巴士數據收集
- KMB: 批量 API (3 次調用，超快)
- CTB: 並行處理優化 (ThreadPool，快很多)
- 智能快取與錯誤處理
- Firebase Storage 自動上傳
- 版本管理機制
"""

import requests
import json
import time
import threading
import os
import sys
import logging
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Any, Tuple, Optional

# Load environment variables first (always needed)
try:
    from dotenv import load_dotenv
    load_dotenv()  # Load .env file immediately
    DOTENV_LOADED = True
except ImportError:
    DOTENV_LOADED = False
    print("⚠️ Warning: python-dotenv not installed. Using default paths.")
    print("   Install with: pip3 install python-dotenv")

# Firebase libraries (optional)
try:
    import firebase_admin
    from firebase_admin import credentials, storage
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    print("⚠️ Warning: Firebase libraries not installed. Upload will be skipped.")
    print("   Install with: pip3 install firebase-admin")

# Setup paths
SCRIPT_DIR = Path(__file__).parent.absolute()

def setup_logging():
    """Configure logging to both file and console"""
    # Get log directory from environment or use default
    log_dir = os.getenv('LOG_DIRECTORY', str(SCRIPT_DIR / 'logs'))
    log_dir_path = Path(log_dir)
    log_dir_path.mkdir(exist_ok=True)

    # Create log file with date
    log_file = log_dir_path / f"bus_data_collection_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler()  # Also print to console
        ]
    )

    logger = logging.getLogger(__name__)
    logger.info(f"Logging initialized: {log_file}")
    return logger

def initialize_firebase() -> bool:
    """Initialize Firebase Admin SDK"""
    if not FIREBASE_AVAILABLE:
        logging.warning("Firebase libraries not available, skipping Firebase initialization")
        return False

    try:
        service_account_path = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH')
        storage_bucket = os.getenv('FIREBASE_STORAGE_BUCKET')

        if not service_account_path:
            logging.error("FIREBASE_SERVICE_ACCOUNT_PATH not set in .env file")
            return False

        if not storage_bucket:
            logging.error("FIREBASE_STORAGE_BUCKET not set in .env file")
            return False

        if not os.path.exists(service_account_path):
            logging.error(f"Firebase service account file not found: {service_account_path}")
            return False

        # Initialize Firebase
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': storage_bucket
        })

        logging.info(f"✅ Firebase initialized: {storage_bucket}")
        return True

    except Exception as e:
        logging.error(f"Failed to initialize Firebase: {e}")
        return False

def upload_to_firebase_storage(local_file_path: str, remote_name: str = 'bus_data.json') -> bool:
    """Upload file to Firebase Storage with version metadata"""
    if not FIREBASE_AVAILABLE:
        logging.warning("Firebase not available, skipping upload")
        return False

    try:
        bucket = storage.bucket()
        blob = bucket.blob(remote_name)

        # Read file to get version info
        with open(local_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # Set metadata including version timestamp
        blob.metadata = {
            'version': str(data.get('version', 0)),
            'generated_at': data.get('generated_at', ''),
            'file_size': str(os.path.getsize(local_file_path)),
            'total_routes': str(data.get('summary', {}).get('total_routes', 0)),
            'total_stops': str(data.get('summary', {}).get('total_stops', 0))
        }

        logging.info(f"📤 Uploading {local_file_path} to Firebase Storage...")
        logging.info(f"   Version: {blob.metadata['version']}")
        logging.info(f"   Size: {blob.metadata['file_size']} bytes")

        # Upload file
        blob.upload_from_filename(
            local_file_path,
            content_type='application/json'
        )

        # Make publicly readable (or use Firebase Auth in app)
        # blob.make_public()  # Uncomment if you want public access

        logging.info(f"✅ Upload successful!")
        logging.info(f"   Blob path: gs://{bucket.name}/{remote_name}")

        return True

    except Exception as e:
        logging.error(f"❌ Firebase upload failed: {e}")
        return False

class OptimizedConcurrentBusDataCollector:
    def __init__(self):
        self.kmb_base = "https://data.etabus.gov.hk/v1/transport/kmb"
        self.ctb_base = "https://rt.data.gov.hk/v2/transport/citybus"

        # Generate version timestamp (Unix timestamp for easy comparison)
        self.version = int(datetime.now().timestamp())

        # 線程安全的數據結構
        self.bus_data = {
            "version": self.version,  # Unix timestamp for version tracking
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

    def validate_data(self) -> bool:
        """Enhanced validation with comprehensive checks and detailed reporting"""
        logging.info("🔍 Validating collected data with enhanced checks...")
        errors = []
        warnings = []
        validation_report = {
            'validation_time': datetime.now().isoformat(),
            'status': 'UNKNOWN',
            'checks': {},
            'warnings': [],
            'errors': []
        }

        # Check 1: Minimum data requirements
        min_routes_check = len(self.bus_data['routes']) >= 1500
        validation_report['checks']['minimum_routes'] = {
            'expected': 1500,
            'actual': len(self.bus_data['routes']),
            'status': 'PASS' if min_routes_check else 'FAIL'
        }
        if not min_routes_check:
            errors.append(f"Too few routes: {len(self.bus_data['routes'])} (expected ≥1500)")

        min_stops_check = len(self.bus_data['stops']) >= 5000
        validation_report['checks']['minimum_stops'] = {
            'expected': 5000,
            'actual': len(self.bus_data['stops']),
            'status': 'PASS' if min_stops_check else 'FAIL'
        }
        if not min_stops_check:
            errors.append(f"Too few stops: {len(self.bus_data['stops'])} (expected ≥5000)")

        # Check 2: Required fields completeness
        missing_fields_count = 0
        missing_field_examples = []
        for route_id, route_info in self.bus_data['routes'].items():
            required_fields = ['route_number', 'company', 'direction', 'origin_tc', 'dest_tc']
            for field in required_fields:
                if not route_info.get(field) or route_info.get(field) == '':
                    missing_fields_count += 1
                    if len(missing_field_examples) < 5:
                        missing_field_examples.append(f"{route_id}.{field}")

        validation_report['checks']['required_fields'] = {
            'missing_count': missing_fields_count,
            'examples': missing_field_examples[:5],
            'status': 'PASS' if missing_fields_count == 0 else 'FAIL'
        }
        if missing_fields_count > 0:
            errors.append(f"{missing_fields_count} missing required fields (examples: {missing_field_examples[:5]})")

        # Check 3: Route-stop consistency
        routes_with_no_stops = []
        for route_id in self.bus_data['routes']:
            if route_id not in self.bus_data['route_stops'] or not self.bus_data['route_stops'][route_id]:
                routes_with_no_stops.append(route_id)

        orphaned_routes_threshold = len(self.bus_data['routes']) * 0.1
        orphaned_check = len(routes_with_no_stops) <= orphaned_routes_threshold
        validation_report['checks']['orphaned_routes'] = {
            'count': len(routes_with_no_stops),
            'threshold': int(orphaned_routes_threshold),
            'examples': routes_with_no_stops[:10],
            'status': 'PASS' if orphaned_check else 'FAIL'
        }
        if not orphaned_check:
            errors.append(f"{len(routes_with_no_stops)} routes have no stops (threshold: {int(orphaned_routes_threshold)})")
        elif len(routes_with_no_stops) > 0:
            warnings.append(f"{len(routes_with_no_stops)} routes have no stops (within threshold)")

        # Check 4: Coordinate validity (Hong Kong bounds + NaN/Infinity check)
        invalid_coords = []
        nan_coords = []
        for stop_id, stop_info in self.bus_data['stops'].items():
            lat = stop_info['latitude']
            lon = stop_info['longitude']

            # Check for NaN or Infinity
            import math
            if math.isnan(lat) or math.isnan(lon) or math.isinf(lat) or math.isinf(lon):
                nan_coords.append(f"{stop_id} (NaN/Inf)")
                continue

            # Check for zero coordinates
            if lat == 0.0 or lon == 0.0:
                invalid_coords.append(f"{stop_id} (0.0)")
                continue

            # Check Hong Kong geographic bounds
            if not (22.0 <= lat <= 22.7 and 113.8 <= lon <= 114.5):
                invalid_coords.append(f"{stop_id} ({lat}, {lon})")

        total_invalid = len(invalid_coords) + len(nan_coords)
        coord_check = total_invalid == 0
        validation_report['checks']['coordinate_validity'] = {
            'invalid_count': total_invalid,
            'nan_inf_count': len(nan_coords),
            'out_of_bounds_count': len(invalid_coords),
            'examples': (nan_coords + invalid_coords)[:10],
            'status': 'PASS' if coord_check else 'FAIL'
        }
        if not coord_check:
            errors.append(f"{total_invalid} stops with invalid coordinates (NaN/Inf: {len(nan_coords)}, Out-of-bounds: {len(invalid_coords)})")

        # Check 5: Stop-route mapping consistency
        orphaned_stops = []
        for stop_id in self.bus_data['stops']:
            if stop_id not in self.bus_data['stop_routes'] or not self.bus_data['stop_routes'][stop_id]:
                orphaned_stops.append(stop_id)

        orphaned_stops_check = len(orphaned_stops) == 0
        validation_report['checks']['stop_route_consistency'] = {
            'orphaned_stops': len(orphaned_stops),
            'examples': orphaned_stops[:10],
            'status': 'PASS' if orphaned_stops_check else 'WARN'
        }
        if not orphaned_stops_check:
            warnings.append(f"{len(orphaned_stops)} stops have no associated routes")

        # Check 6: Direction consistency
        invalid_directions = []
        for route_id, route_info in self.bus_data['routes'].items():
            direction = route_info.get('direction')
            if direction not in ['inbound', 'outbound']:
                invalid_directions.append(f"{route_id}: {direction}")

        direction_check = len(invalid_directions) == 0
        validation_report['checks']['direction_consistency'] = {
            'invalid_count': len(invalid_directions),
            'examples': invalid_directions[:10],
            'status': 'PASS' if direction_check else 'FAIL'
        }
        if not direction_check:
            errors.append(f"{len(invalid_directions)} routes with invalid direction (examples: {invalid_directions[:10]})")

        # Check 7: Company field validity
        invalid_companies = []
        for route_id, route_info in self.bus_data['routes'].items():
            company = route_info.get('company')
            if company not in ['KMB', 'CTB', 'NWFB']:
                invalid_companies.append(f"{route_id}: {company}")

        company_check = len(invalid_companies) == 0
        validation_report['checks']['company_validity'] = {
            'invalid_count': len(invalid_companies),
            'examples': invalid_companies[:10],
            'status': 'PASS' if company_check else 'FAIL'
        }
        if not company_check:
            errors.append(f"{len(invalid_companies)} routes with invalid company (examples: {invalid_companies[:10]})")

        # Save validation report
        validation_report['warnings'] = warnings
        validation_report['errors'] = errors
        validation_report['status'] = 'PASS' if len(errors) == 0 else 'FAIL'

        # Get output directory
        output_dir = os.getenv('OUTPUT_DIRECTORY', str(SCRIPT_DIR))
        report_path = Path(output_dir) / 'validation_report.json'
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(validation_report, f, indent=2, ensure_ascii=False)
        logging.info(f"📄 Validation report saved: {report_path}")

        # Report results
        if errors:
            logging.error("❌ Data validation FAILED:")
            for error in errors:
                logging.error(f"   - {error}")
            return False

        if warnings:
            logging.warning("⚠️  Validation warnings:")
            for warning in warnings:
                logging.warning(f"   - {warning}")

        logging.info("✅ Data validation PASSED")
        logging.info(f"   Routes: {len(self.bus_data['routes']):,}")
        logging.info(f"   Stops: {len(self.bus_data['stops']):,}")
        logging.info(f"   Version: {self.version}")
        logging.info(f"   Warnings: {len(warnings)}")
        return True

    def finalize_and_save(self, filename: str = "bus_data.json") -> str:
        """完成並保存數據"""
        logging.info("📊 Finalizing data...")

        # Get output directory from environment or use script directory
        output_dir = os.getenv('OUTPUT_DIRECTORY', str(SCRIPT_DIR))
        output_dir_path = Path(output_dir)
        output_dir_path.mkdir(parents=True, exist_ok=True)

        # Full file path
        output_file = output_dir_path / filename

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
        logging.info("📈 Final Statistics:")
        logging.info(f"   🚌 Total Routes: {summary['total_routes']:,}")
        logging.info(f"      ├─ KMB: {summary['kmb_routes']:,}")
        logging.info(f"      └─ CTB: {summary['ctb_routes']:,}")
        logging.info(f"   📍 Total Stops: {summary['total_stops']:,}")
        logging.info(f"   🗺️  Stop-Route Mappings: {summary['total_stop_route_mappings']:,}")
        logging.info(f"   📡 API Calls: {summary['api_calls_made']:,} (Success: {summary['success_rate']})")

        # 保存數據
        logging.info(f"💾 Saving to {output_file}...")
        start_time = time.time()

        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(self.bus_data, f, ensure_ascii=False, indent=2)

        save_time = time.time() - start_time

        file_size = os.path.getsize(output_file)
        logging.info(f"✅ Saved in {save_time:.2f}s")
        logging.info(f"📁 File: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")
        logging.info(f"📂 Location: {output_file}")

        return str(output_file)

    def create_backup(self, data_file: str) -> bool:
        """Create backup of previous bus_data.json with automatic cleanup"""
        try:
            data_path = Path(data_file)
            if not data_path.exists():
                logging.info("ℹ️  No existing data file to backup")
                return True

            # Get backup directory
            backup_dir = data_path.parent / 'backup'
            backup_dir.mkdir(exist_ok=True)

            # Create timestamped backup
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_file = backup_dir / f"bus_data_{timestamp}.json"

            # Copy file
            import shutil
            shutil.copy2(data_path, backup_file)
            logging.info(f"💾 Backup created: {backup_file}")

            # Cleanup old backups (keep last 7)
            backups = sorted(backup_dir.glob('bus_data_*.json'), key=lambda p: p.stat().st_mtime, reverse=True)
            if len(backups) > 7:
                for old_backup in backups[7:]:
                    old_backup.unlink()
                    logging.info(f"🗑️  Removed old backup: {old_backup.name}")

            logging.info(f"✅ Backup complete (keeping {min(len(backups), 7)} backups)")
            return True

        except Exception as e:
            logging.error(f"⚠️  Backup failed: {e}")
            return False

    def generate_metadata(self, data_file: str) -> str:
        """Generate metadata file with checksums for version control"""
        import hashlib

        logging.info("📋 Generating metadata file...")

        data_path = Path(data_file)
        if not data_path.exists():
            logging.error(f"Data file not found: {data_file}")
            return ""

        # Calculate checksums
        md5_hash = hashlib.md5()
        sha256_hash = hashlib.sha256()

        with open(data_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                md5_hash.update(chunk)
                sha256_hash.update(chunk)

        md5_checksum = md5_hash.hexdigest()
        sha256_checksum = sha256_hash.hexdigest()

        # Read data for summary
        with open(data_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # Get file size
        file_size = data_path.stat().st_size

        # Create metadata
        metadata = {
            'version': data.get('version'),
            'generated_at': data.get('generated_at'),
            'file_size_bytes': file_size,
            'md5_checksum': md5_checksum,
            'sha256_checksum': sha256_checksum,
            'summary': {
                'total_routes': data.get('summary', {}).get('total_routes', 0),
                'total_stops': data.get('summary', {}).get('total_stops', 0),
                'total_mappings': data.get('summary', {}).get('total_stop_route_mappings', 0),
                'companies': ['KMB', 'CTB', 'NWFB']
            },
            'download_url': f"gs://{os.getenv('FIREBASE_STORAGE_BUCKET', 'your-bucket.appspot.com')}/bus_data.json"
        }

        # Save metadata file
        metadata_file = data_path.parent / 'bus_data_metadata.json'
        with open(metadata_file, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)

        logging.info(f"✅ Metadata generated: {metadata_file}")
        logging.info(f"   MD5: {md5_checksum}")
        logging.info(f"   SHA256: {sha256_checksum[:16]}...")
        logging.info(f"   File size: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")

        return str(metadata_file)

def main():
    """主執行函數 with Firebase upload"""
    # Setup logging first
    logger = setup_logging()

    logger.info("=" * 70)
    logger.info("🚀 Hong Kong Bus Data Collection with Firebase Upload")
    logger.info("⚡ KMB: Batch API + CTB: Concurrent + Firebase Storage")
    logger.info("=" * 70)

    start_time = time.time()
    firebase_enabled = False

    try:
        # Initialize Firebase (if available)
        if FIREBASE_AVAILABLE:
            firebase_enabled = initialize_firebase()
            if not firebase_enabled:
                logger.warning("⚠️ Firebase initialization failed. Data will be saved locally only.")
        else:
            logger.warning("⚠️ Firebase libraries not installed. Data will be saved locally only.")

        # Create collector
        collector = OptimizedConcurrentBusDataCollector()

        # 1. KMB 批量收集
        logger.info("\n" + "=" * 50)
        if not collector.collect_kmb_batch():
            logger.error("❌ KMB collection failed")
            sys.exit(2)

        # 2. CTB 並行收集
        logger.info("\n" + "=" * 50)
        if not collector.collect_ctb_concurrent():
            logger.error("❌ CTB collection failed")
            sys.exit(2)

        # 3. 創建反向映射
        logger.info("\n" + "=" * 50)
        collector.create_reverse_mapping()

        # 4. 驗證資料
        logger.info("\n" + "=" * 50)
        if not collector.validate_data():
            logger.error("❌ Data validation failed")
            sys.exit(2)

        # 5. 備份舊數據
        logger.info("\n" + "=" * 50)
        output_dir = os.getenv('OUTPUT_DIRECTORY', str(SCRIPT_DIR))
        data_file_path = Path(output_dir) / 'bus_data.json'
        collector.create_backup(str(data_file_path))

        # 6. 保存本地檔案
        logger.info("\n" + "=" * 50)
        filename = collector.finalize_and_save()

        # 7. 生成 metadata
        logger.info("\n" + "=" * 50)
        metadata_file = collector.generate_metadata(filename)

        # 8. 上傳到 Firebase
        if firebase_enabled:
            logger.info("\n" + "=" * 50)
            if not upload_to_firebase_storage(filename):
                logger.error("❌ Firebase upload failed")
                sys.exit(1)  # Exit with code 1 for upload failure
        else:
            logger.warning("⚠️ Skipping Firebase upload (not configured)")

        # Success!
        total_time = time.time() - start_time
        logger.info("\n" + "=" * 70)
        logger.info(f"🎉 Collection Complete in {total_time:.2f} seconds!")
        logger.info(f"📄 Local file: {filename}")
        if firebase_enabled:
            logger.info("☁️  Firebase: Uploaded successfully")
        logger.info("✅ Ready for iOS app integration!")

        sys.exit(0)  # Success

    except KeyboardInterrupt:
        logger.warning("\n⏸️  Collection interrupted by user")
        sys.exit(130)  # Standard exit code for SIGINT

    except Exception as e:
        logger.error(f"\n💥 Fatal error: {e}", exc_info=True)
        sys.exit(2)  # General error

if __name__ == "__main__":
    main()