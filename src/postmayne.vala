/*  Copyright (C) 2019 Steven D. Branson. View the LICENSE file at the top level of this project for more information.  */
using Gtk;
using Soup;

public static int main(string[] args) {
    Gtk.init(ref args);

    MainWindow app = new MainWindow();
    app.show_all();
    app.destroy.connect(Gtk.main_quit);

    Gtk.main();

    return 0;
}

public class MainWindow : Window {
    private TextView response_body_text_view;
    private ComboBoxText request_method_combo;
    private Entry url_entry;

    private Grid request_header_grid;
    private int request_header_grid_size = 0;

    private Entry request_body_content_type_entry;
    private TextView request_body_text_view;

    private const string[] REQUEST_METHODS = {
        "GET",
        "POST",
        "PUT",
        "PATCH",
        "DELETE",
        "HEAD",
        "OPTIONS",
        "CONNECT",
        "TRACE"
    };

    public MainWindow() {
        this.title = "Postmayne";
        this.window_position = WindowPosition.CENTER;
        set_default_size(640, 480);

        var header = new HeaderBar();
        header.has_subtitle = false;
        header.show_close_button = true;
        header.title = this.title;
        this.set_titlebar(header);

        // Primary controls

        this.request_method_combo = new ComboBoxText();
        foreach (string method in REQUEST_METHODS) {
            request_method_combo.append_text(method);
        }
        request_method_combo.set_active(0);

        this.url_entry = new Entry();
        url_entry.input_purpose = InputPurpose.URL;

        var send_button = new Button.with_label("Send");
        send_button.clicked.connect(on_send_clicked);
        
        var primary_controls = new Box(Orientation.HORIZONTAL, 2);
        primary_controls.pack_start(request_method_combo, false, false, 2);
        primary_controls.pack_start(url_entry, true, true, 2);
        primary_controls.pack_end(send_button, false, false, 2);

        // Request header controls

        var request_header_container = new Box(Orientation.VERTICAL, 2);
        
        var request_header_controls_heading_container = new Box(Orientation.HORIZONTAL, 2);
        var request_header_controls_heading_label = new Label("Request Headers");
        var request_header_add_button = new Button.with_label("Add");
        request_header_add_button.clicked.connect(add_request_header_row);

        request_header_controls_heading_container.pack_start(request_header_controls_heading_label, false, false, 2);
        request_header_controls_heading_container.pack_end(request_header_add_button, false, false, 2);
        request_header_container.pack_start(request_header_controls_heading_container, true, true, 2);

        this.request_header_grid = new Grid();
        request_header_grid.insert_row(0);
        request_header_grid.insert_column(0);
        request_header_grid.insert_column(1);
        request_header_grid.insert_column(2);
        add_request_header_row();

        request_header_container.pack_start(request_header_grid, true, true, 2);

        // Request body editor

        var request_body_container = new Box(Orientation.VERTICAL, 2);

        var request_body_content_type_container = new Box(Orientation.HORIZONTAL, 2);
        var request_body_content_type_label = new Label("Content-Type");
        request_body_content_type_entry = new Entry();
        request_body_content_type_container.pack_start(request_body_content_type_label, false, false, 2);
        request_body_content_type_container.pack_start(request_body_content_type_entry, true, true, 2);

        request_body_text_view = new TextView();
        var request_body_scrolled_window = new ScrolledWindow(null, null);
        request_body_scrolled_window.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        request_body_scrolled_window.add(request_body_text_view);

        request_body_container.pack_start(request_body_content_type_container, false, false, 2);
        request_body_container.pack_start(request_body_scrolled_window, true, true, 2);

        // Response body view

        response_body_text_view = new TextView ();
        response_body_text_view.editable = false;
        response_body_text_view.cursor_visible = false;

        var response_body_scrolled_window = new ScrolledWindow (null, null);
        response_body_scrolled_window.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        response_body_scrolled_window.add(response_body_text_view);

        // Main box around everything

        var vbox = new Box (Orientation.VERTICAL, 2);
        vbox.pack_start(primary_controls, false, true, 2);
        vbox.pack_start(request_header_container, false, true, 2);
        vbox.pack_start(request_body_container, true, true, 2);
        vbox.pack_start(response_body_scrolled_window, true, true, 2);

        add(vbox);
    }

    private void add_request_header_row() {
        var header_key_entry = new Entry();
        var header_value_entry = new Entry();
        var header_delete_button = new Button.with_label("Remove");
        header_delete_button.clicked.connect(() => {
            remove_request_header_row(header_delete_button);
        });

        request_header_grid.insert_row(0);
        request_header_grid.attach(header_key_entry, 0, 0, 1, 1);
        request_header_grid.attach(header_value_entry, 1, 0, 1, 1);
        request_header_grid.attach(header_delete_button, 2, 0, 1, 1);
        request_header_grid.show_all();
        request_header_grid_size += 1;
        print(@"$request_header_grid_size\n");
    }

    private void remove_request_header_row(Widget header_delete_button) {
        for (int i = 0; i < request_header_grid_size; i++) {
            var widget = request_header_grid.get_child_at(2, i);
            if (widget == header_delete_button) {
                request_header_grid.remove_row(i);
                request_header_grid_size -= 1;
                print(@"$request_header_grid_size\n");
                return;
            }
        }
        print("Couldn't delete request header row for some reason\n");
    }

    private void on_send_clicked() {
        var session = new Session();
        var logger = new Logger(LoggerLogLevel.MINIMAL, -1);
        session.add_feature(logger);

        var message = new Message(request_method_combo.get_active_text(), url_entry.get_text());
        
        // add request body if we have one
        if (request_body_text_view.buffer.get_char_count() > 0) {
            if (request_body_content_type_entry.get_text().length < 1) {
                print("Can't send a request body without content-type.");
                response_body_text_view.buffer.set_text("Can't send a request body without content-type.");
                return;
            }
            var data = request_body_text_view.buffer.text;
            
            print((string)data);

            message.set_request(
                request_body_content_type_entry.get_text(), 
                MemoryUse.COPY, 
                data.data);
        }

        // insert all the key value pairs from the request header grid
        for (int i = 0; i < request_header_grid_size; i++) {
            var key_entry = (Entry)request_header_grid.get_child_at(0, i);
            var val_entry = (Entry)request_header_grid.get_child_at(1, i);
            if (key_entry == null || val_entry == null) {
                continue;
            }
            
            var key = key_entry.get_text();
            var val = val_entry.get_text();
            if (key == null || key.length < 1 || val == null || val.length < 1) {
                continue;
            }

            message.request_headers.append(key, val);
        }

        print(@"$(message.method) $(message.uri.to_string(false))");
        session.queue_message(message, this.on_http_request_complete);
    }

    private void on_http_request_complete(Session session, Message message) {
        if (message == null || message.response_body == null || message.response_body.data == null) {
            response_body_text_view.buffer.set_text("No response body");
            return;
        }
        
        var response_body = (string)message.response_body.data;

        if (response_body.length < 1) {
            response_body_text_view.buffer.set_text("No response body");
            return;
        }

        var response_body_normalized = response_body.normalize();
        // google.com's utf8 is busted or something so we convert to ascii
        if (response_body_normalized == null) {
            response_body_text_view.buffer.set_text(response_body.to_ascii());
        } else {
            response_body_text_view.buffer.set_text(response_body_normalized);
        }
    }
}