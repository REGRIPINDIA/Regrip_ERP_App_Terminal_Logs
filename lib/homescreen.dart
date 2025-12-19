import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart'; // Needed for auto-scroll

// 1. The Provider Model (Unchanged logic, just added scroll helper)
class TerminalProvider with ChangeNotifier {
  static const eventChannel = EventChannel('com.regrip.logs/receiver');

  List<String> _logs = [];
  List<String> get logs => _logs;

  // Filtered logs for search functionality
  String _searchQuery = "";
  List<String> get filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    return _logs.where((log) => log.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  TerminalProvider() {
    _startListening();
  }

  void _startListening() {
    eventChannel.receiveBroadcastStream().listen((dynamic event) {
      _logs.add(event.toString());
      notifyListeners();
    }, onError: (dynamic error) {
      _logs.add("SYSTEM ERROR: ${error.message}");
      notifyListeners();
    });
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }
}

// 2. The UI Page
class TerminalPage extends StatefulWidget {
  @override
  _TerminalPageState createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final ScrollController _scrollController = ScrollController();
  TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TerminalProvider(),
      child: Scaffold(
        backgroundColor: Color(0xFF1E1E1E), // VS Code Dark Background
        appBar: AppBar(
          title: Text("Network Terminal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF252526),
          elevation: 0,
          actions: [
            // Clear Button
            Consumer<TerminalProvider>(
              builder: (context, provider, child) => IconButton(
                icon: Icon(Icons.delete_sweep, color: Colors.redAccent),
                onPressed: provider.clearLogs,
                tooltip: "Clear Logs",
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // --- Search Bar ---
            Container(
              color: Color(0xFF2D2D30),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Consumer<TerminalProvider>(
                  builder: (context, provider, _) {
                    return TextField(
                      controller: _searchController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search logs (e.g. 'ERR', 'user/login')...",
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            provider.search("");
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Color(0xFF3E3E42),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) => provider.search(value),
                    );
                  }
              ),
            ),

            // --- Logs List ---
            Expanded(
              child: Consumer<TerminalProvider>(
                builder: (context, provider, child) {
                  // Auto-scroll trigger
                  SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  if (provider.filteredLogs.isEmpty) {
                    return Center(
                      child: Text("No logs waiting...", style: TextStyle(color: Colors.grey[600])),
                    );
                  }

                 return ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.all(10),
                    itemCount: provider.filteredLogs.length,
                    // 1. Correct syntax: It must be a function (context, index) => Widget
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.white24, // Subtle line for dark theme
                      height: 1,             // Minimal height
                    ),
                    itemBuilder: (context, index) {
                      return LogCard(log: provider.filteredLogs[index]);
                    },

                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. A Beautiful Card Widget for each Log
// 3. A Smart Card Widget that Expands/Collapses
class LogCard extends StatefulWidget {
  final String log;

  const LogCard({required this.log});

  @override
  _LogCardState createState() => _LogCardState();
}

class _LogCardState extends State<LogCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Determine style based on log content
    Color borderColor = Colors.grey;
    Color iconColor = Colors.grey;
    IconData iconData = Icons.info_outline;
    Color bgColor = Color(0xFF2D2D2D);

    if (widget.log.contains("ERR") || widget.log.contains("ERROR")) {
      borderColor = Colors.redAccent;
      iconColor = Colors.redAccent;
      iconData = Icons.error_outline;
      bgColor = Color(0xFF3E2D2D);
    } else if (widget.log.contains("REQ") || widget.log.contains("REQUEST")) {
      borderColor = Colors.blueAccent;
      iconColor = Colors.blueAccent;
      iconData = Icons.cloud_upload_outlined;
    } else if (widget.log.contains("RES") || widget.log.contains("RESPONSE")) {
      borderColor = Colors.greenAccent;
      iconColor = Colors.greenAccent;
      iconData = Icons.cloud_download_outlined;
    }

    return GestureDetector(
      // Toggle expansion on tap
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      // Long press to copy is still supported
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: widget.log));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Log copied to clipboard"), duration: Duration(seconds: 1)),
        );
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(left: BorderSide(color: borderColor, width: 4)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(iconData, size: 16, color: iconColor),
                      SizedBox(width: 8),
                      Text(
                        _getHeaderText(),
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Visual indicator for expansion
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 16,
                  )
                ],
              ),
              SizedBox(height: 8),

              // The Content Logic
              _isExpanded
                  ? SelectableText(
                widget.log,
                style: _logStyle(),
              )
                  : Text(
                widget.log,
                style: _logStyle(),
                maxLines: 5, // Limit to 5 lines
                overflow: TextOverflow.ellipsis, // Add "..." at the end
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _logStyle() {
    return TextStyle(
      color: Colors.white70,
      fontFamily: 'Courier',
      fontSize: 13,
      height: 1.4,
    );
  }

  String _getHeaderText() {
    if (widget.log.contains("ERR")) return "ERROR";
    if (widget.log.contains("REQ")) return "REQUEST";
    if (widget.log.contains("RES")) return "RESPONSE";
    return "INFO";
  }
}