#include <gtk/gtk.h>
#include <gio/gio.h>
#include <stdlib.h>

static int result_code = 1;
static GtkWidget *active_dialog;
static const char *agent_xml =
"<node><interface name='org.bluez.Agent1'>"
"<method name='Release'/>"
"<method name='RequestPinCode'><arg type='o' direction='in'/><arg type='s' direction='out'/></method>"
"<method name='DisplayPinCode'><arg type='o' direction='in'/><arg type='s' direction='in'/></method>"
"<method name='RequestPasskey'><arg type='o' direction='in'/><arg type='u' direction='out'/></method>"
"<method name='DisplayPasskey'><arg type='o' direction='in'/><arg type='u' direction='in'/><arg type='q' direction='in'/></method>"
"<method name='RequestConfirmation'><arg type='o' direction='in'/><arg type='u' direction='in'/></method>"
"<method name='RequestAuthorization'><arg type='o' direction='in'/></method>"
"<method name='AuthorizeService'><arg type='o' direction='in'/><arg type='s' direction='in'/></method>"
"<method name='Cancel'/>"
"</interface></node>";

static void agent_call(GDBusConnection *connection, const gchar *sender, const gchar *path,
    const gchar *interface, const gchar *method, GVariant *parameters,
    GDBusMethodInvocation *invocation, gpointer data) {
    (void)connection; (void)sender; (void)path; (void)interface; (void)data;
    if (g_str_equal(method, "Cancel") || g_str_equal(method, "Release")) {
        if (active_dialog) gtk_dialog_response(GTK_DIALOG(active_dialog), GTK_RESPONSE_CANCEL);
        g_dbus_method_invocation_return_value(invocation, NULL);
        return;
    }
    gboolean entry_needed = g_str_equal(method, "RequestPinCode") || g_str_equal(method, "RequestPasskey");
    gboolean display_only = g_str_has_prefix(method, "Display");
    gchar *message = g_strdup("Allow this Bluetooth device to pair/connect?");
    if (g_str_equal(method, "RequestConfirmation") || g_str_equal(method, "DisplayPasskey")) {
        GVariant *value = g_variant_get_child_value(parameters, 1);
        guint32 passkey = g_variant_get_uint32(value);
        g_variant_unref(value); g_free(message);
        message = g_strdup_printf(display_only ? "Enter %06u on your Bluetooth device, then press Enter." :
            "Does your Bluetooth device show %06u?", passkey);
    } else if (g_str_equal(method, "DisplayPinCode")) {
        GVariant *value = g_variant_get_child_value(parameters, 1);
        g_free(message);
        message = g_strdup_printf("Enter %s on your Bluetooth device.", g_variant_get_string(value, NULL));
        g_variant_unref(value);
    } else if (entry_needed) {
        g_free(message); message = g_strdup("Enter the PIN/passkey shown on your Bluetooth device:");
    }
    if (active_dialog) gtk_widget_destroy(active_dialog);
    GtkWidget *dialog = gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION,
        display_only ? GTK_BUTTONS_CLOSE : GTK_BUTTONS_OK_CANCEL, "%s", message);
    active_dialog = dialog;
    gtk_widget_set_name(dialog, "bluetooth-pair");
    gtk_window_set_title(GTK_WINDOW(dialog), "Bluetooth pairing");
    GtkWidget *entry = NULL;
    if (entry_needed) {
        entry = gtk_entry_new();
        gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), entry);
        gtk_entry_set_activates_default(GTK_ENTRY(entry), TRUE);
        gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
        gtk_entry_set_max_length(GTK_ENTRY(entry), g_str_equal(method, "RequestPasskey") ? 6 : 16);
        gtk_widget_show(entry);
        gtk_widget_grab_focus(entry);
    }
    g_free(message);
    if (display_only) {
        gtk_widget_show(dialog);
        g_dbus_method_invocation_return_value(invocation, NULL);
        return;
    }
    int response = gtk_dialog_run(GTK_DIALOG(dialog));
    if (response != GTK_RESPONSE_OK) {
        g_dbus_method_invocation_return_dbus_error(invocation, "org.bluez.Error.Rejected", "User cancelled");
    } else if (g_str_equal(method, "RequestPinCode")) {
        g_dbus_method_invocation_return_value(invocation, g_variant_new("(s)", gtk_entry_get_text(GTK_ENTRY(entry))));
    } else if (g_str_equal(method, "RequestPasskey")) {
        const char *text = gtk_entry_get_text(GTK_ENTRY(entry));
        char *end; unsigned long value = strtoul(text, &end, 10);
        if (!*text || *end || value > 999999)
            g_dbus_method_invocation_return_dbus_error(invocation, "org.bluez.Error.Rejected", "Invalid passkey");
        else g_dbus_method_invocation_return_value(invocation, g_variant_new("(u)", (guint32)value));
    } else g_dbus_method_invocation_return_value(invocation, NULL);
    gtk_widget_destroy(dialog); active_dialog = NULL;
}
static void paired(GObject *source, GAsyncResult *result, gpointer data) {
    (void)data;
    GError *error = NULL;
    GVariant *reply = g_dbus_connection_call_finish(G_DBUS_CONNECTION(source), result, &error);
    if (reply) { result_code = 0; g_variant_unref(reply); }
    else { g_printerr("%s\n", error->message); g_error_free(error); }
    gtk_main_quit();
}
int main(int argc, char **argv) {
    gtk_init(&argc, &argv);
    if (argc < 2 || argc > 3) return 1;
    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
    if (!bus) { g_printerr("%s\n", error->message); return 1; }
    if (argc >= 3) {
        GtkCssProvider *css = gtk_css_provider_new();
        gtk_css_provider_load_from_path(css, argv[2], NULL);
        gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
            GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_USER);
    }
    GVariant *objects = g_dbus_connection_call_sync(bus, "org.bluez", "/", "org.freedesktop.DBus.ObjectManager",
        "GetManagedObjects", NULL, NULL, 0, 5000, NULL, &error);
    if (!objects) return 1;
    GVariant *map = g_variant_get_child_value(objects, 0), *interfaces;
    GVariantIter iter; const gchar *path; gchar *device_path = NULL;
    g_variant_iter_init(&iter, map);
    while (g_variant_iter_next(&iter, "{&o@a{sa{sv}}}", &path, &interfaces)) {
        GVariant *props = g_variant_lookup_value(interfaces, "org.bluez.Device1", NULL);
        const char *address;
        if (props && g_variant_lookup(props, "Address", "&s", &address) && !g_ascii_strcasecmp(address, argv[1]))
            device_path = g_strdup(path);
        if (props) g_variant_unref(props);
        g_variant_unref(interfaces);
    }
    g_variant_unref(map); g_variant_unref(objects);
    if (!device_path) return 1;
    GDBusNodeInfo *node = g_dbus_node_info_new_for_xml(agent_xml, NULL);
    const GDBusInterfaceVTable vtable = { .method_call = agent_call };
    if (!g_dbus_connection_register_object(bus, "/local/radio/agent", node->interfaces[0], &vtable, NULL, NULL, &error)) return 1;
    GVariant *registered = g_dbus_connection_call_sync(bus, "org.bluez", "/org/bluez", "org.bluez.AgentManager1",
        "RegisterAgent", g_variant_new("(os)", "/local/radio/agent", "KeyboardDisplay"), NULL, 0, 5000, NULL, &error);
    if (!registered) { g_printerr("%s\n", error->message); return 1; }
    g_variant_unref(registered);
    g_dbus_connection_call(bus, "org.bluez", device_path, "org.bluez.Device1", "Pair", NULL, NULL,
        0, 120000, NULL, paired, NULL);
    gtk_main();
    return result_code;
}
