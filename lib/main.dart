import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

const bool isDebugMode = true;
// NOWA NAZWA APLIKACJI
const String appName = "BedtimeReminder";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Konfiguracja parametrów autostartu
  launchAtStartup.setup(appName: appName, appPath: Platform.resolvedExecutable);

  // SPRAWDZENIE: Jeśli nie jest jeszcze zarejestrowana, włącz autostart raz.
  // Dzięki temu przy kolejnych uruchomieniach aplikacja nie będzie "pukać" do rejestru systemowego.
  bool isRegistered = await launchAtStartup.isEnabled();
  if (!isRegistered) {
    await launchAtStartup.enable();
  }

  WindowOptions windowOptions = const WindowOptions(
    size: Size(600, 800),
    center: true,
    title: appName,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Aplikacja startuje ukryta w tle
    await windowManager.hide();
    await windowManager.setPreventClose(true);
  });

  runApp(
    MaterialApp(
      title: appName,
      home: const TimeOutApp(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.blue),
    ),
  );
}

class AlarmBlock {
  String id;
  int startH, startM, endH, endM;
  List<int> weekdays;
  bool isActive;
  String message;

  AlarmBlock({
    required this.id,
    required this.startH,
    required this.startM,
    required this.endH,
    required this.endM,
    required this.weekdays,
    this.isActive = true,
    this.message = "Czas na sen!",
  });

  String get timeRange =>
      "${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')} - ${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}";

  Map<String, dynamic> toJson() => {
    'id': id,
    'sh': startH,
    'sm': startM,
    'eh': endH,
    'em': endM,
    'days': weekdays,
    'active': isActive,
    'msg': message,
  };
  factory AlarmBlock.fromJson(Map<String, dynamic> json) => AlarmBlock(
    id: json['id'],
    startH: json['sh'],
    startM: json['sm'],
    endH: json['eh'],
    endM: json['em'],
    weekdays: List<int>.from(json['days']),
    isActive: json['active'],
    message: json['msg'] ?? "Czas na sen!",
  );
}

class TimeOutApp extends StatefulWidget {
  const TimeOutApp({super.key});
  @override
  State<TimeOutApp> createState() => _TimeOutAppState();
}

class _TimeOutAppState extends State<TimeOutApp>
    with WindowListener, TrayListener {
  bool isBlocked = false;
  String currentLockMessage = "";
  List<AlarmBlock> alarms = [];
  bool isLoading = true;

  GlobalKey keyAddBtn = GlobalKey();
  GlobalKey keyList = GlobalKey();
  GlobalKey keyClose = GlobalKey();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initSystemTray();
    _loadSettings();
    Timer.periodic(const Duration(seconds: 3), (timer) => _checkLogic());
  }

  Future<void> _initSystemTray() async {
    // Wybór ikony w zależności od systemu
    // Windows najlepiej radzi sobie z .ico, Linux/macOS z .png
    String iconPath = Platform.isWindows
        ? 'assets/icon.ico'
        : 'assets/icon.png';

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Bedtime Reminder');
    await windowManager.setIcon(
      'assets/icon.png',
    ); // Dodaj to przed windowManager.show()

    Menu menu = Menu(
      items: [
        MenuItem(
          label: 'Otwórz $appName',
          onClick: (_) => windowManager.show(),
        ),
        MenuItem.separator(),
        MenuItem(label: 'Zakończ aplikację', onClick: (_) => exit(0)),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() => windowManager.show();

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('alarms_v8');
    final bool firstRun = prefs.getBool('first_run_v8') ?? true;

    setState(() {
      if (data != null) {
        alarms = (jsonDecode(data) as List)
            .map((i) => AlarmBlock.fromJson(i))
            .toList();
      }
      isLoading = false;
    });

    if (firstRun) {
      Future.delayed(const Duration(milliseconds: 1000), _showTutorial);
      await prefs.setBool('first_run_v8', false);
    }
  }

  void _showTutorial() {
    List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "Add",
        keyTarget: keyAddBtn,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _tutoText(
              "DODAJ HARMONOGRAM",
              "Tutaj zaplanujesz godziny, w których komputer powinien zostać zablokowany.",
              Icons.add_alarm,
            ),
          ),
        ],
      ),
    );

    if (alarms.isNotEmpty) {
      targets.add(
        TargetFocus(
          identify: "List",
          keyTarget: keyList,
          shape: ShapeLightFocus.RRect,
          radius: 15,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _tutoText(
                "TWOJE LISTY",
                "Kliknij w element, aby go edytować, lub przesuń suwak, aby wyłączyć blokadę bez jej usuwania.",
                Icons.list_alt,
              ),
            ),
          ],
        ),
      );
    }

    targets.add(
      TargetFocus(
        identify: "Close",
        keyTarget: keyClose,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _tutoText(
              "DZIAŁANIE W TLE",
              "BedtimeReminder działa w tle nawet po zamknięciu tego okna. Ikonę znajdziesz w pasku zadań.",
              Icons.visibility_off,
            ),
          ),
        ],
      ),
    );

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.9),
      alignSkip: Alignment.bottomLeft,
      textSkip: "POMIŃ",
      paddingFocus: 10,
    ).show(context: context);
  }

  Widget _tutoText(String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Text(
            desc,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // --- Reszta Twojej logiki (checkLogic, save, build etc.) ---
  // [Zachowano bez zmian funkcjonalnych, zaktualizowano tylko UI]

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarms_v8', jsonEncode(alarms));
  }

  void _checkLogic() async {
    if (isLoading) return;
    final now = DateTime.now();
    AlarmBlock? hittingAlarm;

    for (var alarm in alarms.where(
      (a) => a.isActive && a.weekdays.contains(now.weekday),
    )) {
      int nowMins = now.hour * 60 + now.minute;
      int startMins = alarm.startH * 60 + alarm.startM;
      int endMins = alarm.endH * 60 + alarm.endM;
      bool isHit = (startMins > endMins)
          ? (nowMins >= startMins || nowMins < endMins)
          : (nowMins >= startMins && nowMins < endMins);
      if (isHit) {
        hittingAlarm = alarm;
        break;
      }
    }

    if (hittingAlarm != null && !isBlocked) {
      setState(() => currentLockMessage = hittingAlarm!.message);
      _enableLock();
    } else if (hittingAlarm == null && isBlocked) {
      _disableLock();
    }

    if (isBlocked) {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
    }
  }

  void _enableLock() async {
    if (Navigator.canPop(context)) Navigator.pop(context);
    setState(() => isBlocked = true);
    List<Display> displays = await screenRetriever.getAllDisplays();
    double w = 0;
    double h = 0;
    for (var d in displays) {
      w += d.size.width;
      if (d.size.height > h) h = d.size.height;
    }
    await windowManager.setAsFrameless();
    await windowManager.setBounds(Rect.fromLTWH(0, 0, w, h));
    await windowManager.show();
  }

  void _disableLock() async {
    setState(() => isBlocked = false);
    await windowManager.setHasShadow(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSize(const Size(600, 800));
    await windowManager.center();
  }

  void _debugUnlock() async {
    final now = DateTime.now();
    for (var alarm in alarms) {
      if (alarm.isActive && alarm.weekdays.contains(now.weekday)) {
        int nowMins = now.hour * 60 + now.minute;
        int startMins = alarm.startH * 60 + alarm.startM;
        int endMins = alarm.endH * 60 + alarm.endM;
        bool isHit = (startMins > endMins)
            ? (nowMins >= startMins || nowMins < endMins)
            : (nowMins >= startMins && nowMins < endMins);
        if (isHit) alarm.isActive = false;
      }
    }
    await _save();
    _disableLock();
  }

  @override
  void onWindowClose() async =>
      isBlocked ? await windowManager.focus() : await windowManager.hide();

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (isBlocked) return _buildLockUI();

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showTutorial,
            tooltip: "Instrukcja",
          ),
          IconButton(
            key: keyClose,
            icon: const Icon(Icons.close),
            onPressed: () => windowManager.hide(),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: alarms.length,
        itemBuilder: (context, index) {
          final a = alarms[index];
          return Card(
            key: index == 0 ? keyList : null,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(
                a.timeRange,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text("${_getDaysShort(a.weekdays)}\n\"${a.message}\""),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: a.isActive,
                    onChanged: (v) {
                      setState(() => a.isActive = v);
                      _save();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() => alarms.removeAt(index));
                      _save();
                    },
                  ),
                ],
              ),
              onTap: () => _showEditDialog(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: keyAddBtn,
        onPressed: () => _showEditDialog(-1),
        label: const Text("Nowa blokada"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  String _getDaysShort(List<int> days) {
    const names = ["", "Pn", "Wt", "Śr", "Cz", "Pt", "Sb", "Nd"];
    return days.map((d) => names[d]).join(", ");
  }

  // Dialog edycji (uproszczony na potrzeby wglądu)
  void _showEditDialog(int index) {
    AlarmBlock alarm;
    final TextEditingController msgController = TextEditingController();

    if (index == -1) {
      alarm = AlarmBlock(
        id: DateTime.now().toString(),
        startH: 22,
        startM: 0,
        endH: 6,
        endM: 0,
        weekdays: [1, 2, 3, 4, 5],
      );
    } else {
      alarm = alarms[index];
    }
    msgController.text = alarm.message;

    // Nazwy dni do wyświetlenia
    const List<String> nazwyDni = [
      "Poniedziałek",
      "Wtorek",
      "Środa",
      "Czwartek",
      "Piątek",
      "Sobota",
      "Niedziela",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDs) => AlertDialog(
          title: Text(index == -1 ? "Nowa blokada" : "Edytuj blokadę"),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Wyrównanie do lewej
                children: [
                  const Text(
                    "Treść wyświetlana podczas blokady:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: msgController,
                    onChanged: (v) => alarm.message = v,
                    decoration: const InputDecoration(
                      hintText: "np. Czas spać!",
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Godziny obowiązywania:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Wykorzystuje poprawiony wcześniej _timeButton
                      _timeButton(
                        context,
                        "Start",
                        alarm.startH,
                        alarm.startM,
                        (h, m) => setDs(() {
                          alarm.startH = h;
                          alarm.startM = m;
                        }),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.blueAccent),
                      _timeButton(
                        context,
                        "Koniec",
                        alarm.endH,
                        alarm.endM,
                        (h, m) => setDs(() {
                          alarm.endH = h;
                          alarm.endM = m;
                        }),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text(
                    "Dni tygodnia:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // PRZYWRÓCONY PIONOWY UKŁAD KOLUMNOWY (jak w oryginale)
                  Column(
                    children: List.generate(7, (i) {
                      int d = i + 1; // mapowanie 0-6 na 1-7
                      return CheckboxListTile(
                        title: Text(nazwyDni[i]),
                        value: alarm.weekdays.contains(d),
                        onChanged: (bool? isSelected) {
                          setDs(() {
                            if (isSelected == true) {
                              alarm.weekdays.add(d);
                            } else {
                              alarm.weekdays.remove(d);
                            }
                          });
                        },
                        // Opcjonalne: sprawia, że kafelki są mniejsze
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ANULUJ"),
            ),
            ElevatedButton(
              onPressed: () {
                if (index == -1) setState(() => alarms.add(alarm));
                _save();
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text("ZAPISZ"),
            ),
          ],
        ),
      ),
    );
  }

  // Poprawiony przycisk czasu z formatowaniem 00:00
  Widget _timeButton(
    BuildContext ctx,
    String label,
    int h,
    int m,
    Function(int, int) onPicked,
  ) {
    // Formatowanie: dodaje zero przed minutami/godzinami jeśli są < 10
    String formattedTime =
        "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";

    return InkWell(
      onTap: () async {
        TimeOfDay? p = await showTimePicker(
          context: ctx,
          initialTime: TimeOfDay(hour: h, minute: m),
        );
        if (p != null) onPicked(p.hour, p.minute);
      },
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            formattedTime,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nights_stay, color: Colors.blueAccent, size: 100),
            const SizedBox(height: 30),
            Text(
              currentLockMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Process.run('shutdown', ['/s', '/t', '0']),
              icon: const Icon(Icons.power_settings_new),
              label: const Text("WYŁĄCZ KOMPUTER"),
            ),
            if (isDebugMode)
              TextButton(
                onPressed: _debugUnlock,
                child: const Text(
                  "DEBUG: Odblokuj",
                  style: TextStyle(color: Colors.white24),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
