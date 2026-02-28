#!/usr/bin/env python3
"""
Modern Workspace Switcher for Hyprland
Glassmorphic design matching waybar aesthetic
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gdk, GLib, Gio
import subprocess
import json
import re
from collections import OrderedDict

class WorkspaceSwitcher(Adw.ApplicationWindow):
    def __init__(self, application):
        super().__init__(application=application)
        self.set_title("Workspace Switcher")
        self.set_default_size(800, 500)
        self.set_resizable(False)
        
        # Glassmorphic styling
        self.setup_provider()
        
        # Main container
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        self.main_box.set_margin_top(30)
        self.main_box.set_margin_bottom(30)
        self.main_box.set_margin_start(30)
        self.main_box.set_margin_end(30)
        
        # Header with title
        header = Gtk.Label(label="󰮯 Workspaces")
        header.add_css_class("title-2")
        header.set_margin_bottom(10)
        
        # Workspace grid
        self.workspace_grid = Gtk.Grid()
        self.workspace_grid.set_row_spacing(15)
        self.workspace_grid.set_column_spacing(15)
        self.workspace_grid.set_halign(Gtk.Align.CENTER)
        
        # Action buttons
        actions_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        actions_box.set_halign(Gtk.Align.CENTER)
        actions_box.set_margin_top(20)
        
        add_btn = Gtk.Button(label="󰐕 New Workspace")
        add_btn.add_css_class("suggested-action")
        add_btn.connect("clicked", self.add_workspace)
        
        close_btn = Gtk.Button(label="󰅙 Close")
        close_btn.connect("clicked", self.close)
        
        actions_box.append(add_btn)
        actions_box.append(close_btn)
        
        self.main_box.append(header)
        self.main_box.append(self.workspace_grid)
        self.main_box.append(actions_box)
        
        self.set_content(self.main_box)
        
        # Load initial workspaces
        self.update_workspaces()
        
        # Setup key bindings
        self.setup_keybindings()
        
        # Auto-refresh
        GLib.timeout_add(1000, self.update_workspaces)
    
    def setup_provider(self):
        """Setup CSS provider for glassmorphic styling"""
        css_provider = Gtk.CssProvider()
        css = """
            window {
                background: rgba(30, 30, 40, 0.85);
                border-radius: 20px;
                backdrop-filter: blur(20px);
                -gtk-window-border-radius: 20px;
            }
            
            .workspace-card {
                background: rgba(45, 45, 55, 0.7);
                border-radius: 12px;
                padding: 20px;
                min-width: 120px;
                min-height: 100px;
                border: 1px solid rgba(255, 255, 255, 0.1);
                transition: all 200ms ease-out;
            }
            
            .workspace-card:hover {
                background: rgba(65, 65, 75, 0.8);
                border: 1px solid rgba(255, 255, 255, 0.2);
                transform: translateY(-2px);
            }
            
            .workspace-card.active {
                background: rgba(100, 100, 255, 0.3);
                border: 2px solid rgba(100, 100, 255, 0.6);
            }
            
            .workspace-number {
                font-size: 24px;
                font-weight: bold;
                color: #ffffff;
                margin-bottom: 5px;
            }
            
            .workspace-name {
                font-size: 12px;
                color: rgba(255, 255, 255, 0.7);
            }
            
            .workspace-window-count {
                font-size: 10px;
                color: rgba(255, 255, 255, 0.5);
                margin-top: 5px;
            }
            
            .title-2 {
                font-size: 20px;
                font-weight: bold;
                color: #ffffff;
            }
            
            button {
                background: rgba(55, 55, 65, 0.7);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 8px;
                color: #ffffff;
                padding: 8px 16px;
                transition: all 200ms ease-out;
            }
            
            button:hover {
                background: rgba(75, 75, 85, 0.8);
                border: 1px solid rgba(255, 255, 255, 0.2);
            }
            
            button.suggested-action {
                background: rgba(100, 100, 255, 0.3);
                border: 1px solid rgba(100, 100, 255, 0.6);
            }
            
            button.suggested-action:hover {
                background: rgba(120, 120, 255, 0.4);
            }
        """
        css_provider.load_from_data(css.encode())
        
        style_context = self.get_style_context()
        display = Gdk.Display.get_default()
        style_context.add_provider_for_display(display, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    
    def setup_keybindings(self):
        """Setup keyboard shortcuts"""
        ev_controller = Gtk.EventControllerKey()
        ev_controller.connect("key-pressed", self.on_key_pressed)
        self.add_controller(ev_controller)
    
    def on_key_pressed(self, controller, keyval, keycode, state):
        """Handle keyboard shortcuts"""
        if keyval == Gdk.KEY_Escape:
            self.close()
        elif keyval >= Gdk.KEY_1 and keyval <= Gdk.KEY_9:
            workspace_num = keyval - Gdk.KEY_0
            self.switch_to_workspace(workspace_num)
        elif keyval >= Gdk.KEY_KP_1 and keyval <= Gdk.KEY_KP_9:
            workspace_num = keyval - Gdk.KEY_KP_0
            self.switch_to_workspace(workspace_num)
        return False
    
    def get_hyprland_info(self):
        """Get workspace and window information from Hyprland"""
        try:
            # Get workspaces
            workspaces_result = subprocess.run(['hyprctl', 'workspaces', '-j'], 
                                            capture_output=True, text=True)
            workspaces = json.loads(workspaces_result.stdout)
            
            # Get active workspace
            active_result = subprocess.run(['hyprctl', 'activeworkspace', '-j'], 
                                         capture_output=True, text=True)
            active_workspace = json.loads(active_result.stdout)
            
            # Get clients for window info
            clients_result = subprocess.run(['hyprctl', 'clients', '-j'], 
                                          capture_output=True, text=True)
            clients = json.loads(clients_result.stdout)
            
            return workspaces, active_workspace, clients
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            return [], {'id': 1}, []
    
    def get_workspace_info(self, workspace_id, clients):
        """Get window information for a specific workspace"""
        workspace_clients = [c for c in clients if c['workspace']['id'] == workspace_id]
        window_count = len(workspace_clients)
        
        if window_count > 0:
            # Get the title of the focused window in this workspace
            focused_client = next((c for c in workspace_clients if c.get('focused', False)), workspace_clients[0])
            window_title = focused_client.get('title', 'No title')
            # Truncate long titles
            if len(window_title) > 15:
                window_title = window_title[:12] + "..."
            return window_count, window_title
        return 0, "Empty"
    
    def create_workspace_card(self, workspace, is_active, window_count, window_title):
        """Create a workspace card widget"""
        card = Gtk.Button()
        card.add_css_class("workspace-card")
        if is_active:
            card.add_css_class("active")
        
        # Workspace content
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content.set_valign(Gtk.Align.CENTER)
        
        # Workspace number with icon
        number_label = Gtk.Label()
        icon = "󰮯" if is_active else "󰮮"
        number_label.set_text(f"{icon} {workspace['id']}")
        number_label.add_css_class("workspace-number")
        
        # Window info
        if window_count > 0:
            name_label = Gtk.Label(label=window_title)
            name_label.add_css_class("workspace-name")
            
            count_label = Gtk.Label(label=f"{window_count} window{'s' if window_count != 1 else ''}")
            count_label.add_css_class("workspace-window-count")
            
            content.append(number_label)
            content.append(name_label)
            content.append(count_label)
        else:
            name_label = Gtk.Label(label="Empty")
            name_label.add_css_class("workspace-name")
            content.append(number_label)
            content.append(name_label)
        
        card.set_child(content)
        card.connect("clicked", lambda _: self.switch_to_workspace(workspace['id']))
        
        return card
    
    def update_workspaces(self):
        """Update the workspace grid"""
        workspaces, active_workspace, clients = self.get_hyprland_info()
        
        # Clear existing widgets
        for child in self.workspace_grid:
            self.workspace_grid.remove(child)
        
        # Sort workspaces by ID
        workspaces_sorted = sorted(workspaces, key=lambda x: x['id'])
        
        # Create workspace cards in a grid (3 columns max)
        row, col = 0, 0
        max_cols = 4
        
        for workspace in workspaces_sorted:
            is_active = workspace['id'] == active_workspace['id']
            window_count, window_title = self.get_workspace_info(workspace['id'], clients)
            
            card = self.create_workspace_card(workspace, is_active, window_count, window_title)
            self.workspace_grid.attach(card, col, row, 1, 1)
            
            col += 1
            if col >= max_cols:
                col = 0
                row += 1
        
        # Show the window and update
        self.show()
        return True  # Continue timeout
    
    def switch_to_workspace(self, workspace_id):
        """Switch to the specified workspace"""
        subprocess.run(['hyprctl', 'dispatch', 'workspace', str(workspace_id)], 
                      capture_output=True)
        self.update_workspaces()
    
    def add_workspace(self, btn):
        """Add a new workspace"""
        subprocess.run(['hyprctl', 'dispatch', 'workspace', '+1'], 
                      capture_output=True)
        self.update_workspaces()

class WorkspaceApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id='com.example.workspaceswitcher')
        self.connect('activate', self.on_activate)
    
    def on_activate(self, app):
        win = WorkspaceSwitcher(app)
        win.present()

if __name__ == "__main__":
    app = WorkspaceApp()
    app.run()