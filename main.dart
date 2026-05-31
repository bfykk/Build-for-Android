import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:process_run/process_run.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '音乐工具箱',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthCheckPage(),
    );
  }
}

// ======================== 全局配置 ========================
const cloudPwdUrl = "https://gist.githubusercontent.com/bfykk/caf39d4f3b05b136d412302ed4fbb39d/raw/5b7f0fb5a1e2acaa3a9a24f14749b3914af79a81/password.txt";
late String toolDir;
late String configAlbum;
late String configMusic;

Future<void> initPaths() async {
  final appDir = await getApplicationDocumentsDirectory();
  toolDir = "${appDir.path}/MusicTool";
  configAlbum = "$toolDir/album_config.json";
  configMusic = "$toolDir/music_config.json";
  await Directory(toolDir).create(recursive: true);
}

// ======================== 授权逻辑 ========================
Future<String> getCloudPwd() async {
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(cloudPwdUrl));
    final res = await req.close();
    return await res.transform(utf8.decoder).join();
  } catch (e) {
    return "";
  }
}

Future<bool> isExpired() async {
  final file = File(configAlbum);
  if (!await file.exists()) return true;
  final jsonData = jsonDecode(await file.readAsString());
  final expire = jsonData["expire_time"];
  if (expire == null || expire.toString().isEmpty) return true;
  try {
    final expDate = DateTime.parse(expire.toString());
    return DateTime.now().isAfter(expDate);
  } catch (e) {
    return true;
  }
}

Future<void> saveExpire(int days) async {
  final file = File(configAlbum);
  Map<String, dynamic> data = {};
  if (await file.exists()) {
    data = jsonDecode(await file.readAsString());
  }
  data["expire_time"] = DateTime.now().add(Duration(days: days)).toIso8601String();
  await file.writeAsString(jsonEncode(data));
}

// ======================== 页面：授权检查 ========================
class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await initPaths();
    await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
    final expired = await isExpired();
    if (expired) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PasswordPage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainTabPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ======================== 页面：密码输入 ========================
class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final ctrl = TextEditingController();
  String err = "";

  Future<void> check() async {
    final input = ctrl.text.trim();
    final cloud = await getCloudPwd();
    if (cloud.isNotEmpty && input == cloud.trim()) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TimeSelectPage()));
    } else {
      setState(() => err = "密码不正确");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("请输入管理密码", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: check, child: const Text("验证")),
            if (err.isNotEmpty) Text(err, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

// ======================== 页面：时长选择 ========================
class TimeSelectPage extends StatelessWidget {
  const TimeSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("选择使用时长", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await saveExpire(1);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainTabPage()));
              },
              child: const Text("1天"),
            ),
            ElevatedButton(
              onPressed: () async {
                await saveExpire(30);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainTabPage()));
              },
              child: const Text("30天"),
            ),
            ElevatedButton(
              onPressed: () async {
                await saveExpire(365);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainTabPage()));
              },
              child: const Text("1年"),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================== 主页面：标签栏 ========================
class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(tabs: [
          Tab(text: "🎵 音乐处理"),
          Tab(text: "📀 专辑创建"),
        ]),
        body: TabBarView(
          children: [
            const MusicProcessTab(),
            AlbumCreateTab(),
          ],
        ),
      ),
    );
  }
}

// ======================== 标签1：音乐处理（完整移植你的功能） ========================
class MusicProcessTab extends StatefulWidget {
  const MusicProcessTab({super.key});

  @override
  State<MusicProcessTab> createState() => _MusicProcessTabState();
}

class _MusicProcessTabState extends State<MusicProcessTab> {
  String inputDir = "/storage/emulated/0/Music";
  String outputDir = "/storage/emulated/0/Music/Output";
  int transpose = 0;
  double volume = 0;
  double speed = 1.0;
  String format = "wav";
  double progress = 0;
  String status = "就绪";
  final previewCtrl = TextEditingController();

  final formats = ["mp3", "wav", "flac", "ogg", "m4a"];

  String cleanName(String name) {
    name = name.replaceAll(RegExp(r'\..*$'), "");
    name = name.replaceAll(RegExp(r'[\(\[【].*?[\)\]】]'), "");
    name = name.replaceAll(RegExp(r'[-_&].*'), "");
    return name.trim();
  }

  void preview() {
    final dir = Directory(inputDir);
    if (!dir.existsSync()) {
      previewCtrl.text = "请选择输入目录";
      return;
    }
    final files = dir.listSync().where((f) {
      final low = f.path.toLowerCase();
      return low.endsWith(".mp3") || low.endsWith(".wav") || low.endsWith(".flac") || low.endsWith(".m4a");
    });
    String text = "";
    for (final f in files) {
      final name = File(f.path).uri.pathSegments.last;
      text += "原：$name\n提取：${cleanName(name)}\n\n";
    }
    setState(() => previewCtrl.text = text);
  }

  Future<void> startProcess() async {
    setState(() {
      status = "处理中";
      progress = 0;
    });
    final dir = Directory(inputDir);
    final files = dir.listSync().where((f) {
      final low = f.path.toLowerCase();
      return low.endsWith(".mp3") || low.endsWith(".wav") || low.endsWith(".flac") || low.endsWith(".m4a");
    }).toList();

    final total = files.length;
    for (var i = 0; i < total; i++) {
      final file = files[i];
      final name = File(file.path).uri.pathSegments.last;
      final outName = "${cleanName(name)}.$format";
      final outPath = "$outputDir/$outName";
      await Directory(outputDir).create(recursive: true);

      final pitch = 2.0 * (transpose / 12.0);
      final filter = "asetrate=44100*$pitch,atempo=${speed / pitch},volume=${volume}dB";

      await runExecutableArguments(
        "ffmpeg",
        [
          "-i", file.path,
          "-filter_complex", filter,
          "-ar", "44100",
          "-y", outPath,
        ],
        verbose: false,
      );

      setState(() => progress = (i + 1) / total);
    }

    setState(() {
      status = "✅ 处理完成";
      progress = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("输入文件夹"),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: inputDir),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text("选择"),
          ),
          const SizedBox(height: 8),
          const Text("输出文件夹"),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: outputDir),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text("选择"),
          ),
          const SizedBox(height: 12),
          Text("音调：$transpose"),
          Slider(
            min: -12,
            max: 12,
            value: transpose.toDouble(),
            onChanged: (v) => setState(() => transpose = v.round()),
          ),
          const SizedBox(height: 8),
          Text("音量：${volume.toStringAsFixed(1)}dB"),
          Slider(
            min: -20,
            max: 20,
            value: volume,
            onChanged: (v) => setState(() => volume = v),
          ),
          const SizedBox(height: 8),
          Text("速度：${speed.toStringAsFixed(1)}"),
          Slider(
            min: 0.5,
            max: 2.0,
            value: speed,
            onChanged: (v) => setState(() => speed = v),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: preview, child: const Text("预览歌名")),
          TextField(
            controller: previewCtrl,
            maxLines: 6,
            readOnly: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButton(
            value: format,
            items: formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => format = v.toString()),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          Text(status, textAlign: TextAlign.center),
          ElevatedButton(onPressed: startProcess, child: const Text("开始处理")),
        ],
      ),
    );
  }
}

// ======================== 标签2：专辑创建（完整移植你的功能） ========================
class AlbumCreateTab extends StatefulWidget {
  const AlbumCreateTab({super.key});

  @override
  State<AlbumCreateTab> createState() => _AlbumCreateTabState();
}

class _AlbumCreateTabState extends State<AlbumCreateTab> {
  String source = "/storage/emulated/0/Music";
  String target = "/storage/emulated/0/Albums";
  String imgFolder = "/storage/emulated/0/Covers";
  int per = 10;
  List<String> names = [];
  final nameCtrl = TextEditingController();

  void updateNames() {
    final lines = nameCtrl.text.trim().split("\n").where((l) => l.trim().isNotEmpty);
    setState(() {
      names = lines.map((l) => "歌手 《$l》").toList();
    });
  }

  Future<void> create() async {
    final musicDir = Directory(source);
    if (!musicDir.existsSync()) return;
    final songs = musicDir.listSync().where((f) {
      final low = f.path.toLowerCase();
      return low.endsWith(".mp3") || low.endsWith(".wav") || low.endsWith(".flac") || low.endsWith(".m4a");
    }).toList();

    for (var i = 0; i < names.length; i++) {
      final dir = Directory("$target/${names[i]}");
      await dir.create(recursive: true);
      final segment = songs.sublist(i * per, (i + 1) * per);
      for (final s in segment) {
        final name = File(s.path).uri.pathSegments.last;
        await File(s.path).copy("${dir.path}/$name");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(onPressed: () {}, child: const Text("歌曲文件夹")),
          Text(source),
          ElevatedButton(onPressed: () {}, child: const Text("保存位置")),
          Text(target),
          ElevatedButton(onPressed: () {}, child: const Text("封面图文件夹")),
          Text(imgFolder),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "每专辑数量", border: OutlineInputBorder()),
            onChanged: (v) => per = int.tryParse(v) ?? 10,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            maxLines: 4,
            decoration: const InputDecoration(labelText: "专辑名（每行一个）", border: OutlineInputBorder()),
          ),
          ElevatedButton(onPressed: updateNames, child: const Text("生成列表")),
          const SizedBox(height: 8),
          ...names.map((n) => Text(n)).toList(),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: create, child: const Text("开始创建")),
        ],
      ),
    );
  }
}