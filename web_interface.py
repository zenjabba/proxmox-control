#!/usr/bin/env python3

from flask import Flask, render_template, request, jsonify
from proxmox_maintenance import ProxmoxMaintenance, load_config
import logging
import os

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.route('/')
def index():
    """Render the main page."""
    return render_template('index.html')

@app.route('/api/nodes', methods=['GET'])
def get_nodes():
    """Get list of all nodes in the cluster."""
    try:
        config = load_config()
        proxmox = ProxmoxMaintenance(
            config['host'],
            config['user'],
            config['password']
        )
        nodes = proxmox.get_cluster_nodes()
        return jsonify({'status': 'success', 'nodes': nodes})
    except Exception as e:
        logger.error(f"Error getting nodes: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/maintenance', methods=['POST'])
def start_maintenance():
    """Start maintenance mode for a node."""
    try:
        node = request.json.get('node')
        if not node:
            return jsonify({'status': 'error', 'message': 'Node parameter is required'}), 400

        config = load_config()
        proxmox = ProxmoxMaintenance(
            config['host'],
            config['user'],
            config['password']
        )
        
        if proxmox.process_node(node):
            return jsonify({'status': 'success', 'message': f'Node {node} is now in maintenance mode'})
        else:
            return jsonify({'status': 'error', 'message': f'Failed to put node {node} into maintenance mode'}), 500
            
    except Exception as e:
        logger.error(f"Error during maintenance: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000) 