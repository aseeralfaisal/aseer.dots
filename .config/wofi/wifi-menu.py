#!/usr/bin/env python3
"""Wi-Fi chooser for Waybar, using NetworkManager and Wofi."""
import os
from pathlib import Path
import re
import subprocess

CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'wofi'


def nm(*args, **kwargs):
    return subprocess.run(['nmcli', '--wait', '25', *args], text=True,
                          capture_output=True, **kwargs)


def notify(message):
    subprocess.run(['notify-send', 'Wi-Fi', message], check=False)


def choose(rows, prompt='Wi-Fi', password=False):
    command = ['/usr/bin/wofi', '--dmenu', '--style', str(CONFIG / 'clipboard.css'),
               '--prompt', prompt, '--width', '420', '--height', '600',
               '--location', 'top_right', '--columns', '1', '--lines', '0',
               '--cache-file', '/dev/null']
    if password:
        command += ['--password']
    else:
        command += ['--define', 'dmenu-print_line_num=true', '--no-custom-entry']
    result = subprocess.run(command, input='\n'.join(rows), text=True, capture_output=True)
    return result.stdout.rstrip('\n') if result.returncode == 0 else None


def main():
    devices = nm('-t', '-f', 'DEVICE,TYPE', 'device', 'status')
    if devices.returncode:
        notify(devices.stderr.strip())
        return
    interface = next((line.split(':')[0] for line in devices.stdout.splitlines()
                      if line.endswith(':wifi')), None)
    if not interface:
        notify('No Wi-Fi adapter found.')
        return
    enabled = nm('-t', '-f', 'WIFI', 'general').stdout.strip() == 'enabled'
    rows = ['Turn Wi-Fi off' if enabled else 'Turn Wi-Fi on',
            'Disconnect current network', 'Refresh networks', 'Connection settings']
    networks = []
    if enabled:
        result = nm('-t', '-f', 'IN-USE,BSSID,SSID,SIGNAL,SECURITY',
                    'device', 'wifi', 'list', 'ifname', interface)
        for line in result.stdout.splitlines():
            fields = [re.sub(r'\\(.)', r'\1', field)
                      for field in re.split(r'(?<!\\):', line)]
            if len(fields) != 5:
                continue
            active, bssid, ssid, signal, security = fields
            if not ssid:
                continue
            networks.append((bssid, ssid, security))
            rows.append(f'{"✓ " if active == "*" else ""}{ssid}   {signal}%   {security or "Open"}')
    selection = choose(rows)
    if selection is None or not selection.isdigit():
        return
    index = int(selection)
    if index == 0:
        result = nm('radio', 'wifi', 'off' if enabled else 'on')
    elif index == 1:
        result = nm('device', 'disconnect', interface)
    elif index == 2:
        result = nm('device', 'wifi', 'rescan', 'ifname', interface)
        if result.returncode == 0:
            return main()
    elif index == 3:
        subprocess.Popen(['gnome-control-center', 'wifi'])
        return
    elif 0 <= index - 4 < len(networks):
        bssid, ssid, security = networks[index - 4]
        result = nm('device', 'wifi', 'connect', bssid, 'ifname', interface)
        if result.returncode and security and security != '--':
            password = choose([], f'Password for {ssid}', password=True)
            if password is None:
                return
            # Send the secret over stdin, never in process arguments or files.
            result = nm('--ask', 'device', 'wifi', 'connect', bssid,
                        'ifname', interface, input=password + '\n')
    else:
        return
    notify('Connection updated.' if result.returncode == 0 else
           result.stderr.strip() or 'Connection failed. Check Connection settings.')


if __name__ == '__main__':
    main()
