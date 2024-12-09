import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FlutterApp());
}

class FlutterApp extends StatelessWidget {
  const FlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(primaryColor: Colors.blue),
      darkTheme: ThemeData.dark().copyWith(primaryColor: Colors.blueGrey),
      home: const HomeScreen(),
    );
  }
}

class Quote {
  String text;
  int likes;

  Quote(this.text, {this.likes = 0});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ValueNotifier<bool> _dark = ValueNotifier<bool>(false);
  final ValueNotifier<double> _widthFactor = ValueNotifier<double>(1.0);
  List<Quote> _quotes = [];

  @override
  void initState() {
    super.initState();
    _loadQuotes();
    _initializeLinks();
  }

  // CSVファイルから聖句を読み込む
  Future<void> _loadQuotes() async {
    try {
      final String data = await rootBundle.loadString('assets/聖句.csv');
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(data);
      setState(() {
        _quotes = csvData
            .where((row) => row.isNotEmpty && row[0] != null)  // 空の行や null のデータを除外
            .map((row) => Quote(row[0].toString()))
            .toList();
      });
    } catch (e) {
      print("エラー: 聖句の読み込みに失敗しました: $e");
    }
  }

  // app_links を使用してディープリンクを初期化
  void _initializeLinks() async {
    try {
      final appLinks = AppLinks();

      // 初期リンクを取得
      final initialLink = await appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink as String);
      }

      // リンクストリームのリスナーを設定
      appLinks.uriLinkStream.listen((Uri? link) {
        if (link != null) {
          _handleDeepLink(link.toString());
        }
      });
    } catch (e) {
      print("ディープリンクの処理中にエラーが発生しました: $e");
    }
  }

  // ディープリンクを処理する
  void _handleDeepLink(String link) async {
    print("ディープリンク: $link");

    // リンクIDを抽出 (例: myapp://seisyo)
    try {
      final linkId = link.split('/').last;

      // Firestoreからリンク情報を取得
      await _navigateToLinkPage(linkId);
    } catch (e) {
      print("ディープリンク処理中にエラー: $e");
    }
  }

  // Firestoreから遷移先を取得して、遷移処理を行う
  Future<void> _navigateToLinkPage(String linkId) async {
    try {
      // Firestoreの'links'コレクションからリンク情報を取得
      final docSnapshot = await FirebaseFirestore.instance.collection('links').doc(linkId).get();
      if (docSnapshot.exists) {
        // リンクのデータが存在する場合、遷移先を取得
        final destination = docSnapshot['destination'];
        final quoteId = docSnapshot['quoteId'];

        if (destination == 'quote' && quoteId != null) {
          // 遷移先が'quote'の場合、QuoteScreenに遷移
          final quote = _quotes.firstWhere(
                (quote) => quote.text.contains(quoteId),
            orElse: () => Quote('該当する聖句が見つかりません'),
          );

          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => QuoteScreen(quote: quote),
          ));
        } else {
          print('Firestoreからのリンク情報に問題があります。');
        }
      } else {
        print('リンク情報がFirestoreに存在しません。');
      }
    } catch (e) {
      print('Firestoreからリンク情報の取得に失敗しました: $e');
    }
  }

  void _navigateToQuoteScreen() {
    if (_quotes.isNotEmpty) {
      final randomQuote = _quotes[Random().nextInt(_quotes.length)];
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => QuoteScreen(
          quote: randomQuote,
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('聖句が読み込まれていません')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _dark,
      builder: (context, isDark, child) {
        return ValueListenableBuilder<double>(
          valueListenable: _widthFactor,
          builder: (context, factor, child) {
            return Scaffold(
              backgroundColor: isDark ? Colors.black : Colors.white,
              appBar: AppBar(
                title: const Text('ランダム聖書'),
                actions: [
                  Switch(
                    value: _dark.value,
                    onChanged: (value) {
                      _dark.value = value;
                    },
                  ),
                  DropdownButton<double>(
                    value: _widthFactor.value,
                    onChanged: (value) {
                      if (value != null) {
                        _widthFactor.value = value;
                      }
                    },
                    items: const [
                      DropdownMenuItem<double>(value: 0.5, child: Text('サイズ: 50%')),
                      DropdownMenuItem<double>(value: 0.75, child: Text('サイズ: 75%')),
                      DropdownMenuItem<double>(value: 1.0, child: Text('サイズ: 100%')),
                    ],
                  ),
                ],
              ),
              body: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * _widthFactor.value,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? Colors.grey[800] : Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '今日の一節',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 45,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton(
                        onPressed: _navigateToQuoteScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('聖書をめくる'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class QuoteScreen extends StatefulWidget {
  final Quote quote;

  const QuoteScreen({super.key, required this.quote});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  int _likes = 0;

  void _incrementLikes() {
    setState(() {
      _likes++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        title: const Text('今日の一節'),
      ),
      body: Center(
        child: Container(
          width: 390,
          height: 844,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '今日の一節',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.quote.text,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'いいね: $_likes',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _incrementLikes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('いいね'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
