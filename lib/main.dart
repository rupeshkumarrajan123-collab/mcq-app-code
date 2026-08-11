import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_pkg;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MCQApp());
}

class MCQApp extends StatelessWidget {
  const MCQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCQ Practice App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const QuizScreen(),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Database? _db;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  String? _selectedOption;
  bool _showSolution = false;
  bool _isLoading = true;

  final String _githubUrl =
      "https://raw.githubusercontent.com/rupeshkumarrajan123-collab/mcq-bank/refs/heads/main/week1.json";

  @override
  void initState() {
    super.initState();
    _initDatabaseAndFetch();
  }

  Future<void> _initDatabaseAndFetch() async {
    final dbPath = await getDatabasesPath();
    final path = path_pkg.join(dbPath, 'mcq_bank.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE questions (
            id INTEGER PRIMARY KEY,
            question TEXT,
            options TEXT,
            correct TEXT,
            solution TEXT
          )
        ''');
      },
    );

    await _loadFromLocalDB();
    await _fetchFromGitHub();
  }

  Future<void> _loadFromLocalDB() async {
    if (_db == null) return;
    final List<Map<String, dynamic>> maps = await _db!.query('questions');

    if (maps.isNotEmpty) {
      setState(() {
        _questions = maps.map((q) {
          return {
            'id': q['id'],
            'question': q['question'],
            'options': jsonDecode(q['options'] as String),
            'correct': q['correct'],
            'solution': q['solution'],
          };
        }).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFromGitHub() async {
    try {
      final response = await http.get(Uri.parse(_githubUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        for (var item in data) {
          await _db!.insert(
            'questions',
            {
              'id': item['id'],
              'question': item['question'],
              'options': jsonEncode(item['options']),
              'correct': item['correct'],
              'solution': item['solution'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await _loadFromLocalDB();
      }
    } catch (e) {
      await _loadFromLocalDB();
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _showSolution = false;
      });
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _selectedOption = null;
        _showSolution = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("MCQ Practice")),
        body: Center(
          child: ElevatedButton(
            onPressed: _initDatabaseAndFetch,
            child: const Text("Fetch Questions from GitHub"),
          ),
        ),
      );
    }

    final currentQ = _questions[_currentIndex];
    final List<dynamic> options = currentQ['options'];

    return Scaffold(
      appBar: AppBar(
        title: Text("Question ${_currentIndex + 1} of ${_questions.length}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Syncing with GitHub...")),
              );
              _fetchFromGitHub();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  currentQ['question'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final optionText = options[index].toString();
                  final isSelected = _selectedOption == optionText;
                  final isCorrect = optionText == currentQ['correct'];

                  Color cardColor = Colors.white;
                  if (_showSolution) {
                    if (isCorrect) cardColor = Colors.green.shade100;
                    if (isSelected && !isCorrect) cardColor = Colors.red.shade100;
                  } else if (isSelected) {
                    cardColor = Colors.indigo.shade50;
                  }

                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(optionText),
                      onTap: () {
                        setState(() {
                          _selectedOption = optionText;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            if (_showSolution)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAlignment.start,
                  children: [
                    Text(
                      "Correct Answer: ${currentQ['correct']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Solution: ${currentQ['solution']}"),
                  ],
                ),
              ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _showSolution
                      ? null
                      : () {
                          setState(() {
                            _showSolution = true;
                          });
                        },
                  child: const Text("Show Solution"),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentIndex > 0 ? _previousQuestion : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _currentIndex < _questions.length - 1
                      ? _nextQuestion
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

