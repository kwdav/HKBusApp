#!/usr/bin/env python3
"""
手動上傳 bus_data.json 和 bus_data_metadata.json 到 Firebase Storage

使用方式:
  python3 manual_upload_firebase.py

環境變數 (.env 文件):
  FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/service-account.json
  FIREBASE_STORAGE_BUCKET=your-project.appspot.com
"""

import os
import sys
import json
import hashlib
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv

# Check Firebase libraries
try:
    import firebase_admin
    from firebase_admin import credentials, storage
except ImportError:
    print("❌ Error: Firebase libraries not installed")
    print("   Install with: pip3 install firebase-admin python-dotenv")
    sys.exit(1)


def calculate_checksums(file_path):
    """計算 MD5 和 SHA256 校驗碼"""
    md5_hash = hashlib.md5()
    sha256_hash = hashlib.sha256()

    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b""):
            md5_hash.update(chunk)
            sha256_hash.update(chunk)

    return md5_hash.hexdigest(), sha256_hash.hexdigest()


def verify_environment():
    """驗證環境變數配置"""
    service_account_path = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH')
    storage_bucket = os.getenv('FIREBASE_STORAGE_BUCKET')

    errors = []

    if not service_account_path:
        errors.append("FIREBASE_SERVICE_ACCOUNT_PATH not set in .env")
    elif not os.path.exists(service_account_path):
        errors.append(f"Service account file not found: {service_account_path}")

    if not storage_bucket:
        errors.append("FIREBASE_STORAGE_BUCKET not set in .env")

    if errors:
        print("❌ Environment configuration errors:")
        for error in errors:
            print(f"   - {error}")
        return False

    return True


def initialize_firebase():
    """初始化 Firebase Admin SDK"""
    try:
        service_account_path = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH')
        storage_bucket = os.getenv('FIREBASE_STORAGE_BUCKET')

        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': storage_bucket
        })

        print(f"✅ Firebase initialized: {storage_bucket}")
        return True

    except Exception as e:
        print(f"❌ Failed to initialize Firebase: {e}")
        return False


def generate_or_verify_metadata(data_path):
    """生成或驗證 metadata 文件"""
    data_file = Path(data_path)
    metadata_file = data_file.parent / 'bus_data_metadata.json'

    # Read data file
    with open(data_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Calculate checksums
    md5_checksum, sha256_checksum = calculate_checksums(data_file)
    file_size = data_file.stat().st_size

    # Check if metadata exists and is up-to-date
    if metadata_file.exists():
        with open(metadata_file, 'r', encoding='utf-8') as f:
            existing_metadata = json.load(f)

        # Verify MD5 match
        if existing_metadata.get('md5_checksum') == md5_checksum:
            print(f"✅ Metadata file exists and matches: {metadata_file}")
            return str(metadata_file)
        else:
            print(f"⚠️  Metadata outdated, regenerating...")

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
        'download_url': f"gs://{os.getenv('FIREBASE_STORAGE_BUCKET')}/bus_data.json"
    }

    # Save metadata
    with open(metadata_file, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)

    print(f"📋 Metadata generated: {metadata_file}")
    print(f"   Version: {metadata['version']}")
    print(f"   MD5: {md5_checksum}")
    print(f"   File size: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")

    return str(metadata_file)


def upload_file(local_path, remote_name, content_type='application/json'):
    """上傳文件到 Firebase Storage"""
    try:
        bucket = storage.bucket()
        blob = bucket.blob(remote_name)

        # Read metadata if it's the data file
        if remote_name == 'bus_data.json':
            with open(local_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # Set blob metadata
            blob.metadata = {
                'version': str(data.get('version', 0)),
                'generated_at': data.get('generated_at', ''),
                'file_size': str(Path(local_path).stat().st_size),
                'total_routes': str(data.get('summary', {}).get('total_routes', 0)),
                'total_stops': str(data.get('summary', {}).get('total_stops', 0))
            }

        # Upload file
        blob.upload_from_filename(local_path, content_type=content_type)

        # Get file size
        file_size = Path(local_path).stat().st_size

        print(f"✅ Uploaded: {remote_name} ({file_size:,} bytes / {file_size/1024/1024:.2f} MB)")
        return True

    except Exception as e:
        print(f"❌ Upload failed for {remote_name}: {e}")
        return False


def main():
    """主執行函數"""
    print("=" * 70)
    print("🔥 HKBusApp - Manual Firebase Upload")
    print("=" * 70)
    print()

    # Load environment variables
    load_dotenv()

    # Verify environment
    if not verify_environment():
        sys.exit(1)

    # Get data file path
    script_dir = Path(__file__).parent.absolute()
    output_dir = os.getenv('OUTPUT_DIRECTORY', str(script_dir))
    data_file = Path(output_dir) / 'bus_data.json'

    # Check if data file exists
    if not data_file.exists():
        print(f"❌ Data file not found: {data_file}")
        print("   Please run collect_bus_data_optimized_concurrent.py first")
        sys.exit(1)

    print(f"📂 Data file: {data_file}")
    print()

    # Generate or verify metadata
    metadata_file = generate_or_verify_metadata(str(data_file))
    print()

    # Initialize Firebase
    if not initialize_firebase():
        sys.exit(1)
    print()

    # Upload bus_data.json
    print("📤 Uploading bus_data.json...")
    if not upload_file(str(data_file), 'bus_data.json'):
        sys.exit(1)
    print()

    # Upload bus_data_metadata.json
    print("📤 Uploading bus_data_metadata.json...")
    if not upload_file(metadata_file, 'bus_data_metadata.json'):
        sys.exit(1)
    print()

    # Success
    print("=" * 70)
    print("🎉 Upload Complete!")
    print()

    # Display summary
    with open(metadata_file, 'r', encoding='utf-8') as f:
        metadata = json.load(f)

    print("📊 Upload Summary:")
    print(f"   Version: {metadata['version']}")
    print(f"   Generated: {metadata['generated_at']}")
    print(f"   File size: {metadata['file_size_bytes']:,} bytes")
    print(f"   MD5: {metadata['md5_checksum']}")
    print(f"   Routes: {metadata['summary']['total_routes']:,}")
    print(f"   Stops: {metadata['summary']['total_stops']:,}")
    print()
    print(f"☁️  Firebase URL: {metadata['download_url']}")
    print("✅ Ready for iOS app download!")
    print("=" * 70)


if __name__ == '__main__':
    main()
