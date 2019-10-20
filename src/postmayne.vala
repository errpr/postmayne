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
    private TextView text_view;
    private ComboBoxText request_method_combo;
    private Entry url_entry;

    public MainWindow() {
        this.title = "Postmayne";
        this.window_position = WindowPosition.CENTER;
        set_default_size(640, 480);

        var header = new HeaderBar();
        header.has_subtitle = false;
        header.show_close_button = true;
        header.title = this.title;
        this.set_titlebar(header);

        this.request_method_combo = new ComboBoxText();
        request_method_combo.append_text("GET");
        request_method_combo.append_text("POST");
        request_method_combo.append_text("PUT");
        request_method_combo.append_text("PATCH");
        request_method_combo.append_text("DELETE");
        request_method_combo.append_text("HEAD");
        request_method_combo.append_text("OPTIONS");
        request_method_combo.append_text("CONNECT");
        request_method_combo.append_text("TRACE");
        request_method_combo.set_active(0);

        this.url_entry = new Entry();
        url_entry.input_purpose = InputPurpose.URL;

        var send_button = new Button.with_label("Send");
        send_button.clicked.connect(on_send_clicked);
        
        var primary_controls = new Box(Orientation.HORIZONTAL, 0);
        primary_controls.pack_start(request_method_combo, false, false, 0);
        primary_controls.pack_start(url_entry, true, true, 0);
        primary_controls.pack_end(send_button, false, false, 0);

        this.text_view = new TextView ();
        this.text_view.editable = false;
        this.text_view.cursor_visible = false;

        var scroll = new ScrolledWindow (null, null);
        scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scroll.add (this.text_view);

        var vbox = new Box (Orientation.VERTICAL, 0);
        vbox.pack_start (primary_controls, false, true, 0);
        vbox.pack_start (scroll, true, true, 0);
        add (vbox);
    }

    private static async void read_lines_async (InputStream stream, TextView text_view) throws IOError {
        DataInputStream data_stream = new DataInputStream (stream);
        string line;

        var sb = new StringBuilder();

        while ((line = yield data_stream.read_line_async()) != null) {
            sb.append(@"$line\n");
        }

        text_view.buffer.set_text(sb.str);

    }

    private void on_send_clicked() {
        var session = new Session();
        var logger = new Logger(LoggerLogLevel.MINIMAL, -1);
        session.add_feature(logger);
        
        try {
            var request = session.request_http(this.request_method_combo.get_active_text(), this.url_entry.get_text());
            var message = request.get_message();

            print(message.method);
            print(message.uri.to_string(false));
            message.request_headers.foreach((name, val) => {
                print(@"$name : $val\n");
            });

            request.send_async.begin(null, (obj, res) => {
                try {
                    InputStream stream = request.send_async.end(res);

                    read_lines_async.begin (stream, this.text_view, (obj, res) => {
                        print("hello");
                    });

                } catch (Error e) {
                    stderr.printf("Error: %s\n", e.message);
                }
            });
        } catch (Error e) {
            stderr.printf("Error: %s\n", e.message);
        }
    }
}