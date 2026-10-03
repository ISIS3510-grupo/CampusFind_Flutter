import 'package:campusfind_flutter/services/match_analytics_service.dart';
import 'package:flutter/material.dart';

class MatchAnalyticsScreen extends StatefulWidget {
  const MatchAnalyticsScreen({super.key});

  @override
  State<MatchAnalyticsScreen> createState() => _MatchAnalyticsScreenState();
}

class _MatchAnalyticsScreenState extends State<MatchAnalyticsScreen> {
  final MatchAnalyticsService _analyticsService = MatchAnalyticsService();
  late Future<double> _percentageFuture;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  void _loadMetrics() {
    setState(() {
      _percentageFuture = _analyticsService.getMatchReviewPercentage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas de Negocio (BQ)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Actualizar métricas',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<double>(
          future: _percentageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error al calcular métricas: ${snapshot.error}'),
              );
            }

            final percentage = snapshot.data ?? 0.0;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Enunciado de la Pregunta de Negocio
                  const Card(
                    color: Colors.indigo,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Question',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'What percentage of students review a possible match after receiving a notification?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Métrica Principal: Porcentaje
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32.0,
                        horizontal: 16.0,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Tasa de Revisión de Matches',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: percentage >= 50.0
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );  
  }
}