#!/usr/bin/env python3

import sys
import time
from proxmoxer import ProxmoxAPI
import argparse
from typing import List, Dict, Any
import logging
import configparser
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def load_config(config_path: str = '.proxmox') -> Dict[str, str]:
    """Load Proxmox configuration from file."""
    if not os.path.exists(config_path):
        logger.error(f"Configuration file {config_path} not found!")
        logger.info("Please create a .proxmox file based on .proxmox.template")
        sys.exit(1)
        
    config = configparser.ConfigParser()
    config.read(config_path)
    
    required_fields = ['host', 'user', 'password']
    for field in required_fields:
        if field not in config['proxmox']:
            logger.error(f"Missing required field '{field}' in configuration file")
            sys.exit(1)
            
    return {
        'host': config['proxmox']['host'],
        'user': config['proxmox']['user'],
        'password': config['proxmox']['password']
    }

class ProxmoxMaintenance:
    def __init__(self, host: str, user: str, password: str, verify_ssl: bool = True):
        """Initialize Proxmox connection."""
        self.proxmox = ProxmoxAPI(
            host,
            user=user,
            password=password,
            verify_ssl=verify_ssl
        )
        
    def get_cluster_nodes(self) -> List[str]:
        """Get list of all nodes in the cluster."""
        nodes = self.proxmox.nodes.get()
        return [node['node'] for node in nodes]
    
    def get_node_vms(self, node: str) -> List[Dict[str, Any]]:
        """Get list of running VMs on a specific node."""
        vms = self.proxmox.nodes(node).qemu.get()
        return [vm for vm in vms if vm['status'] == 'running']
    
    def get_node_resources(self, node: str) -> Dict[str, float]:
        """Get resource usage of a node."""
        status = self.proxmox.nodes(node).status.get()
        return {
            'cpu_usage': float(status['cpu']),
            'memory_usage': float(status['memory']['used']) / float(status['memory']['total']),
            'free_memory': float(status['memory']['free'])
        }
    
    def find_destination_node(self, source_node: str, vm_memory: int) -> str:
        """Find the best destination node for migration."""
        nodes = self.get_cluster_nodes()
        nodes.remove(source_node)
        
        best_node = None
        max_free_memory = 0
        
        for node in nodes:
            resources = self.get_node_resources(node)
            if resources['free_memory'] > vm_memory and resources['free_memory'] > max_free_memory:
                max_free_memory = resources['free_memory']
                best_node = node
        
        return best_node
    
    def migrate_vm(self, source_node: str, vm_id: int, target_node: str) -> bool:
        """Migrate a VM to another node."""
        try:
            task = self.proxmox.nodes(source_node).qemu(vm_id).migrate.post(
                target=target_node,
                online=1
            )
            
            # Wait for migration to complete
            while True:
                task_status = self.proxmox.nodes(source_node).tasks(task).status.get()
                if task_status['status'] == 'stopped':
                    if task_status['exitstatus'] == 'OK':
                        return True
                    else:
                        return False
                time.sleep(5)
                
        except Exception as e:
            logger.error(f"Error migrating VM {vm_id}: {str(e)}")
            return False
    
    def put_node_maintenance(self, node: str) -> bool:
        """Put a node into maintenance mode."""
        try:
            self.proxmox.nodes(node).status.post(command='maintenance')
            return True
        except Exception as e:
            logger.error(f"Error putting node {node} into maintenance mode: {str(e)}")
            return False
    
    def process_node(self, target_node: str) -> bool:
        """Process a node for maintenance mode."""
        logger.info(f"Starting maintenance process for node {target_node}")
        
        # Get running VMs
        vms = self.get_node_vms(target_node)
        if not vms:
            logger.info(f"No running VMs found on node {target_node}")
            return self.put_node_maintenance(target_node)
        
        # Migrate each VM
        for vm in vms:
            vm_id = vm['vmid']
            vm_memory = vm['maxmem']
            
            destination = self.find_destination_node(target_node, vm_memory)
            if not destination:
                logger.error(f"No suitable destination found for VM {vm_id}")
                return False
            
            logger.info(f"Migrating VM {vm_id} to node {destination}")
            if not self.migrate_vm(target_node, vm_id, destination):
                logger.error(f"Failed to migrate VM {vm_id}")
                return False
        
        # Put node into maintenance mode
        return self.put_node_maintenance(target_node)

def main():
    parser = argparse.ArgumentParser(description='Put Proxmox node into maintenance mode')
    parser.add_argument('--config', default='.proxmox', help='Path to configuration file (default: .proxmox)')
    parser.add_argument('--node', required=True, help='Target node to put into maintenance mode')
    parser.add_argument('--no-verify-ssl', action='store_true', help='Disable SSL verification')
    
    args = parser.parse_args()
    
    try:
        # Load configuration
        config = load_config(args.config)
        
        proxmox = ProxmoxMaintenance(
            config['host'],
            config['user'],
            config['password'],
            not args.no_verify_ssl
        )
        
        if proxmox.process_node(args.node):
            logger.info(f"Successfully put node {args.node} into maintenance mode")
            sys.exit(0)
        else:
            logger.error(f"Failed to put node {args.node} into maintenance mode")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main() 