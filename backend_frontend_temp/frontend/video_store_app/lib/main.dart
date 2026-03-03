import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const VideoStoreApp());
}

class VideoStoreApp extends StatelessWidget {
  const VideoStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Video Store',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const RecommendationScreen(),
    );
  }
}

// --- 1. The Data Model (Matches your JSON) ---
class MovieRecommendation {
  final String title;
  final int socialProof;
  final int availableStock;
  final String discConditions;

  MovieRecommendation({
    required this.title,
    required this.socialProof,
    required this.availableStock,
    required this.discConditions,
  });

  factory MovieRecommendation.fromJson(Map<String, dynamic> json) {
    return MovieRecommendation(
      title: json['title'] ?? 'Unknown Title',
      socialProof: json['social_proof'] ?? 0,
      availableStock: json['available_stock'] ?? 0,
      discConditions: json['disc_conditions'] ?? 'Unknown',
    );
  }
}

// --- 2. The UI Screen ---
class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  List<MovieRecommendation> recommendations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRecommendations();
  }

  // Function to call your Python API
  Future<void> fetchRecommendations() async {
    // Note: Use http://127.0.0.1:5000 for macOS Desktop/iOS Simulator
    // Use http://10.0.2.2:5000 if testing on Android Emulator
    // Updated port to 5001
    final url = Uri.parse('http://127.0.0.1:5001/api/recommendations/1');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          recommendations = data.map((json) => MovieRecommendation.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        // --- NEW CODE STARTS HERE ---
        // This will print the actual error from Python to your Flutter console
        print("SERVER ERROR: ${response.body}"); 
        throw Exception('Failed to load data: ${response.statusCode}');
        // --- NEW CODE ENDS HERE ---
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Recommendations'),
        backgroundColor: Colors.deepPurple.shade100,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : recommendations.isEmpty
              ? const Center(child: Text("No recommendations found."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recommendations.length,
                  itemBuilder: (context, index) {
                    final movie = recommendations[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            movie.socialProof.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          movie.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text("Stock: ${movie.availableStock} discs"),
                            Text(
                              "Condition: ${movie.discConditions}",
                              style: TextStyle(
                                color: movie.discConditions.contains('Scratched') 
                                    ? Colors.orange 
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                    );
                  },
                ),
    );
  }
}