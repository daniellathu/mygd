import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/cloudinary_service.dart';
import '../../services/weather_service.dart';
import 'mygarden_taskview.dart';
import 'add_plant_dialog.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MyGardenPlantList extends StatefulWidget {
  const MyGardenPlantList({super.key});

  @override
  MyGardenPlantListState createState() => MyGardenPlantListState();
}

class MyGardenPlantListState extends State<MyGardenPlantList> {
  late Stream<QuerySnapshot> userPlantsStream;
  String searchQuery = '';
  final CloudinaryService _cloudinaryService = CloudinaryService();
  Map<String, String> plantImageCache = {};
  
  // Weather variables
  late WeatherService _weatherService;
  double temperature = 0.0;
  String weatherCondition = 'Unknown';
  String cityName = '';
  bool isLoadingWeather = true;
  late Timer _weatherUpdateTimer;

  @override
  void initState() {
    super.initState();
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'defaultUserId';
    userPlantsStream = FirebaseFirestore.instance
        .collection('UserPlants')
        .where('userId', isEqualTo: userId)
        .snapshots();
    _fetchPlantImages();
    
    // Initialize weather service with your API key
    _weatherService = WeatherService('ab71a5a7461d08be8573bdd947fb6285');
    _fetchWeatherData();
    
    // Update weather every 15 minutes
    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _fetchWeatherData();
    });
  }
  
  @override
  void dispose() {
    _weatherUpdateTimer.cancel();
    super.dispose();
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      isLoadingWeather = true;
    });
    
    try {
      // Get current location and weather
      final city = await _weatherService.getCurrentCity();
      final weather = await _weatherService.getWeather(city);
      
      setState(() {
        temperature = weather.temperature;
        weatherCondition = weather.condition;
        cityName = weather.cityName;
        isLoadingWeather = false;
      });
    } catch (e) {
      print('Error fetching weather: $e');
      setState(() {
        isLoadingWeather = false;
      });
    }
  }

  Future<void> _fetchPlantImages() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('PlantLibrary').get();
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String commonName = data['commonName'] as String;
        String? imageUrl = data['PlantImage'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          plantImageCache[commonName] = imageUrl;
        }
      }
      setState(() {});
    } catch (e) {
      print('Error fetching plant images: $e');
    }
  }

  Future<void> _deletePlant(String plantId) async {
    try {
      await FirebaseFirestore.instance.collection('UserPlants').doc(plantId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plant deleted successfully")),
      );
    } catch (e) {
      print('Error deleting plant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete plant")),
      );
    }
  }

  void _confirmDelete(String plantId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Plant"),
        content: const Text("Are you sure you want to delete this plant?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlant(plantId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddPlantDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AddPlantDialog();
      },
    );
  }

  Widget _buildPlantCard(Map<String, dynamic> plant) {
    String plantId = plant['plantId'] ?? "";
    String plantName = plant['plantName'] ?? "Unnamed Plant";
    String commonName = plant['commonName'] ?? "Unknown Species";
    String? imageUrl = plantImageCache[commonName] ?? plant['PlantImage'];
    
    // Extract planting date and format it
    String startDate = plant['startDate'] != null 
        ? DateFormat('MMM dd, yyyy').format((plant['startDate'] as Timestamp).toDate())
        : 'Unknown';
    
    // Extract growth type
    String growthType = plant['growthType'] ?? "FromSeed";
    bool isFromSeed = growthType == "FromSeed";
    
    // Check if planted today
    bool isPlantedToday = false;
    if (plant['startDate'] != null) {
      DateTime startDateTime = (plant['startDate'] as Timestamp).toDate();
      DateTime now = DateTime.now();
      isPlantedToday = startDateTime.day == now.day && 
                      startDateTime.month == now.month && 
                      startDateTime.year == now.year;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyGardenTaskView(
              plantId: plantId,
              commonName: commonName,
              growthType: plant['growthType'] ?? "FromSeed",
            ),
          ),
        );
      },
      onLongPress: () => _confirmDelete(plantId), // Long press to delete
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with overlays
            Stack(
              children: [
                // Plant image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Image.network(
                    imageUrl ?? 'https://via.placeholder.com/150',
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                
                // Growth type pill (top left)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFromSeed ? Icons.emoji_nature : Icons.spa,
                          color: Colors.green,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFromSeed ? 'Seed' : 'Plant',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Today pill (if planted today) (top right)
                if (isPlantedToday)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Planting date (bottom right)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          startDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Plant name and type
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plantName,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold, 
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    commonName,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF4FC3F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isLoadingWeather 
        ? const Center(
            child: SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
          )
        : Row(
            children: [
              Icon(
                _getWeatherIcon(weatherCondition),
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weatherCondition,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    cityName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${temperature.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
    );
  }
  
  IconData _getWeatherIcon(String condition) {
    condition = condition.toLowerCase();
    
    if (condition.contains('clear') || condition.contains('sun')) {
      return Icons.wb_sunny;
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return Icons.water_drop;
    } else if (condition.contains('cloud')) {
      return Icons.cloud;
    } else if (condition.contains('thunderstorm') || condition.contains('storm')) {
      return Icons.thunderstorm;
    } else if (condition.contains('snow')) {
      return Icons.ac_unit;
    } else if (condition.contains('fog') || condition.contains('mist') || condition.contains('haze')) {
      return Icons.cloud_queue;
    } else {
      return Icons.cloud;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom app bar - matching plant_library.dart style
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF2E7D32),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "My Garden",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const Spacer(),
                    // Weather refresh button
                    GestureDetector(
                      onTap: _fetchWeatherData,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Color(0xFF2E7D32),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              _buildWeatherWidget(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search plants...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: userPlantsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.nature,
                              size: 70,
                              color: Colors.green.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Your garden is empty",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Add some plants to get started!",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    } else {
                      List<DocumentSnapshot> plants = snapshot.data!.docs;
                      List<DocumentSnapshot> filteredPlants = plants.where((plant) {
                        var plantData = plant.data() as Map<String, dynamic>;
                        return plantData['plantName'].toString().toLowerCase().contains(searchQuery) ||
                            plantData['commonName'].toString().toLowerCase().contains(searchQuery);
                      }).toList();

                      if (filteredPlants.isEmpty) {
                        return Center(
                          child: Text(
                            'No plants match "$searchQuery"',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        );
                      }

                      // Use GridView instead of ListView for 2 plants per row
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filteredPlants.length,
                        itemBuilder: (context, index) {
                          var plantData = filteredPlants[index].data() as Map<String, dynamic>;
                          return _buildPlantCard(plantData);
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlantDialog,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
