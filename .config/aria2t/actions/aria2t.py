#!/usr/bin/env python3
import xmlrpc.client
import sys, os

gid = sys.argv[1]
token = 'token:' + os.environ.get('ARIA_RPC_SECRET', '')
url = 'http://%s:%s/rpc' % (os.environ.get('ARIA_RPC_HOST', '127.0.0.1'), os.environ.get('ARIA_RPC_PORT', '6800'))

s = xmlrpc.client.ServerProxy(url)

def chcwd():
	r = s.aria2.tellStatus(token, gid, ['bittorrent', 'files', 'dir'])
	if r.get('bittorrent', {}).get('mode', 'single') == 'multi':
		[dir, file] = [os.path.join(r['dir'], r['bittorrent']['info']['name']), '.']
	else:
		[dir, file] = [r['dir'], r['files'][0]['path']]

	os.chdir(dir);
	return file
