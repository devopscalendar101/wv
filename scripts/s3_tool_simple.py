#!/usr/bin/env python3
"""
S3 Tool - Simplified version for GitHub Actions
Handles S3 operations: upload, download, check, delete
"""

import os
import sys
import boto3
from botocore.exceptions import ClientError
import argparse

def upload_to_s3(bucket, key, file_path):
    """Upload file to S3"""
    try:
        s3_client = boto3.client('s3')
        s3_client.upload_file(file_path, bucket, key)
        print(f"Successfully uploaded {file_path} to s3://{bucket}/{key}")
        return True
    except ClientError as e:
        print(f"Error uploading to S3: {e}")
        return False

def download_from_s3(bucket, key, local_path):
    """Download file from S3"""
    try:
        s3_client = boto3.client('s3')
        file_name = os.path.basename(key)
        local_file = os.path.join(local_path, file_name)
        os.makedirs(local_path, exist_ok=True)
        s3_client.download_file(bucket, key, local_file)
        print(f"Successfully downloaded s3://{bucket}/{key} to {local_file}")
        return True
    except ClientError as e:
        print(f"Error downloading from S3: {e}")
        return False

def check_exists_in_s3(bucket, key):
    """Check if file exists in S3"""
    try:
        s3_client = boto3.client('s3')
        s3_client.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError:
        return False

def delete_from_s3(bucket, key):
    """Delete file from S3"""
    try:
        s3_client = boto3.client('s3')
        s3_client.delete_object(Bucket=bucket, Key=key)
        print(f"Successfully deleted s3://{bucket}/{key}")
        return True
    except ClientError as e:
        print(f"Error deleting from S3: {e}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='S3 operations tool')
    parser.add_argument('-m', '--mode', required=True, choices=['upload', 'download', 'check', 'delete'])
    parser.add_argument('-b', '--bucket', required=True, help='S3 bucket name')
    parser.add_argument('-k', '--key', required=True, help='S3 key (path)')
    parser.add_argument('--path', help='Local file path (for upload/download)')
    
    args = parser.parse_args()
    
    if args.mode == 'upload':
        if not args.path or not os.path.exists(args.path):
            print(f"Error: File not found: {args.path}")
            sys.exit(1)
        success = upload_to_s3(args.bucket, args.key, args.path)
        sys.exit(0 if success else 1)
    
    elif args.mode == 'download':
        if not args.path:
            print("Error: --path required for download")
            sys.exit(1)
        success = download_from_s3(args.bucket, args.key, args.path)
        sys.exit(0 if success else 1)
    
    elif args.mode == 'check':
        exists = check_exists_in_s3(args.bucket, args.key)
        print('true' if exists else 'false')
        sys.exit(0 if exists else 1)
    
    elif args.mode == 'delete':
        success = delete_from_s3(args.bucket, args.key)
        sys.exit(0 if success else 1)
