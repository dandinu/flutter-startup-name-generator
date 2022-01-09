import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:basic_utils/basic_utils.dart';
import 'dart:ui';
import 'dart:async';
import 'package:http/http.dart';

import 'favorites_list.dart';

// START: RandomWords Stateful Widget
class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  _RandomWordsState createState() => _RandomWordsState();
}
// END: RandomWords Stateful Widget

class _RandomWordsState extends State<RandomWords> {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  final _suggestions = <String>[];
  Set<String> _saved = Set<String>();
  // final _com = true;
  final _biggerFont = const TextStyle(fontSize: 18.0);

  @override
  void initState() {
    super.initState();
    loadPrefs();
  }

  void loadPrefs() async {
    final SharedPreferences prefs = await _prefs;
    List<String> saved = prefs.getStringList("saved") ?? <String>[];
    _saved = saved.map((String str) {
      final beforeNonLeadingCapitalLetter = RegExp(r"(?=(?!^)[A-Z])");
      List<String> splitPascalCase(String input) =>
          input.split(beforeNonLeadingCapitalLetter);
      List<String> words = splitPascalCase(str);
      return WordPair(words[0], words[1]).toString();
    }).toSet();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
        ],
      ),
      body: _buildSuggestions(),
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FavoriteList(
            data: _saved, savePrefs: savePrefs, biggerFont: _biggerFont),
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, i) {
        if (i.isOdd) return Divider();

        final index = i ~/ 2;

        if (index >= _suggestions.length) {
          _suggestions
              .addAll(generateWordPairs().take(10).map((f) => f.asPascalCase));
        }

        return _buildRow(_suggestions[index]);
      },
    );
  }

  void savePrefs(Set<String> _saved) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setStringList('saved', _saved.toList());
  }

  Widget _buildRow(String pair) {
    final alreadySaved = _saved.contains(pair);
    Future<String> _getDomainAvailability(String name, String ext) async {
      try {
        final response = await get(Uri.parse('https://rdap.verisign.com/' +
            ext +
            '/v1/domain/' +
            name +
            '.' +
            ext));
        if (response.statusCode == 200) {
          return '';
        } else {
          return '.' + ext;
        }
      } on Exception catch (e) {
        return 'Failed to get domain availability: $e';
      }
    }

    return ListTile(
        title: Text(
          pair,
          style: _biggerFont,
        ),
        trailing: Wrap(
          spacing: 12,
          children: [
            FutureBuilder<String>(
              future: _getDomainAvailability(pair, 'com'), // async work
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(),
                    );
                  default:
                    if (snapshot.hasError)
                      return Text('Error: ${snapshot.error}');
                    else
                      return Text('${snapshot.data}');
                }
              },
            ),
            FutureBuilder<String>(
              future: _getDomainAvailability(pair, 'net'), // async work
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(),
                    );
                  default:
                    if (snapshot.hasError)
                      return Text('Error: ${snapshot.error}');
                    else
                      return Text('${snapshot.data}');
                }
              },
            ),
            Icon(
              alreadySaved ? Icons.favorite : Icons.favorite_border,
              color: alreadySaved ? Colors.red : null,
              semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
            ),
          ],
        ),
        onTap: () {
          setState(() {
            if (alreadySaved) {
              _saved.remove(pair);
              savePrefs(_saved);
            } else {
              _saved.add(pair);
              savePrefs(_saved);
            }
          });
        },
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: pair));
          final snackBar = SnackBar(
            content: const Text('Copied to clipboard'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        });
  }
}
