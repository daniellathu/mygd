import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/cloudinary_service.dart';
import 'package:uuid/uuid.dart';

class AddPlantDialog extends StatefulWidget {
  const AddPlantDialog({super.key});

  @override
  _AddPlantDialogState createState() => _AddPlantDialogState();
}

class _AddPlantDialogState extends State<AddPlantDialog> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  // Form controllers
  final _plantNameController = TextEditingController();
  final _commonNameController = TextEditingController();
  
  // Selected values
  String? _selectedPlantId;
  String? _selectedCommonName;
  String _growthType = 'From Seed';
  DateTime _startDate = DateTime.now();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allPlants = []; // All plants from the library
  final bool _isSearching = false;
  bool _isAdding = false;
  bool _locationPermissionGranted = false;
  bool _isLoadingPlants = true;
  
  // Growth type options - only "From Seed" and "From Plant"
  final List<String> _growthTypes = ['From Seed', 'From Plant'];

  @override
  void initState() {
    super.initState();
    // Initialize Cloudinary if needed
    try {
      CloudinaryService.ensureInitialized();
    } catch (e) {
      print('Cloudinary initialization error: $e');
    }
    
    // Request location permission
    _checkLocationPermission();
    
    // Load all plants
    _loadAllPlants();
  }

  Future<void> _loadAllPlants() async {
    setState(() {
      _isLoadingPlants = true;
    });
    
    try {
      // Get all plants from the PlantLibrary collection
      QuerySnapshot snapshot = await _firestore.collection('PlantLibrary').get();
      
      List<Map<String, dynamic>> plants = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        plants.add({
          'id': doc.id,
          'commonName': data['commonName'] ?? 'Unknown',
          'scientificName': data['PlantSpecies'] ?? '',
          'imageUrl': data['PlantImage'] ?? '',
        });
      }
      
      // Sort alphabetically by common name
      plants.sort((a, b) => (a['commonName'] as String).compareTo(b['commonName'] as String));
      
      setState(() {
        _allPlants = plants;
        _isLoadingPlants = false;
      });
    } catch (e) {
      print('Error loading plants: $e');
      setState(() {
        _isLoadingPlants = false;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    setState(() {
      _locationPermissionGranted = permission == LocationPermission.whileInUse || 
                                 permission == LocationPermission.always;
    });
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    _commonNameController.dispose();
    super.dispose();
  }

  // Search plant in the library
  void _searchPlants(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Filter the already loaded plants instead of querying Firestore again
    final filteredPlants = _allPlants.where((plant) => 
      plant['commonName'].toString().toLowerCase().contains(query.toLowerCase())
    ).toList();

    setState(() {
      _searchResults = filteredPlants;
    });
  }

  // Show date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // Add plant to user's garden
  Future<void> _addPlant() async {
    if (_plantNameController.text.isEmpty || _selectedCommonName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to add a plant')),
        );
        return;
      }

      final String plantId = const Uuid().v4();
      final DocumentReference plantRef = FirebaseFirestore.instance.collection('UserPlants').doc(plantId);

      await plantRef.set({
        'plantId': plantId,
        'userId': user.uid,
        'plantName': _plantNameController.text,
        'commonName': _selectedCommonName,
        'plantLibraryId': _selectedPlantId,
        'startDate': Timestamp.fromDate(_startDate),
        'growthType': _growthType.replaceAll(' ', ''),
        'createdAt': FieldValue.serverTimestamp(),
        'currentTaskNumber': 1,
        'completedTasks': 0,
        'isFirstDay': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_plantNameController.text} added to your garden!')),
        );
      }
    } catch (e) {
      print('Error adding plant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding plant: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  // Toggle plant selection (select or deselect)
  void _togglePlantSelection(String id, String commonName) {
    setState(() {
      // If this plant is already selected, deselect it
      if (_selectedPlantId == id) {
        _selectedPlantId = null;
        _selectedCommonName = null;
        _searchQuery = '';
        // Clear the search field when deselecting
        _searchResults = [];
      } else {
        // Otherwise select it
        _selectedPlantId = id;
        _selectedCommonName = commonName;
        _searchQuery = commonName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0
        ),
        child: contentBox(context),
      ),
    );
  }

  Widget contentBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Plant to Garden',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Plant Name Field
            TextField(
              controller: _plantNameController,
              decoration: InputDecoration(
                labelText: 'Your Plant Name *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),
            
            // Plant Type / Common Name Search
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Plant Type / Common Name',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchResults = [];
                                _selectedPlantId = null;
                                _selectedCommonName = null;
                              });
                            },
                          )
                        : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        if (value.isEmpty) {
                          _searchResults = [];
                        }
                      });
                      _searchPlants(value);
                    },
                    controller: TextEditingController(text: _searchQuery)..selection = TextSelection.fromPosition(
                      TextPosition(offset: _searchQuery.length),
                    ),
                  ),
                ),
                
                if (_isLoadingPlants)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  
                // Display plant options - either search results or all plants
                _searchQuery.isEmpty
                    ? _buildSwipeablePlantRow()
                    : _buildSearchResultsList(),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Selected plants display
            if (_selectedCommonName != null)
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                    label: Text(_selectedCommonName!),
                    backgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ],
              ),
              
            const SizedBox(height: 16),
            
            // Planting Date Selector
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Start Date *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMMM d, yyyy').format(_startDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Growth Type Dropdown
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Growth Type *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              value: _growthType,
              onChanged: (newValue) {
                setState(() {
                  _growthType = newValue!;
                });
              },
              items: _growthTypes.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 30),
            
            // Add to Garden Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAdding ? null : _addPlant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isAdding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Add to Garden',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // New widget to display plants in a horizontal swipeable row
  Widget _buildSwipeablePlantRow() {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: _allPlants.isEmpty
          ? const Center(
              child: Text("No plants available", style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _allPlants.length,
              itemBuilder: (context, index) {
                final plant = _allPlants[index];
                final bool isSelected = _selectedPlantId == plant['id'];
                
                return GestureDetector(
                  onTap: () => _togglePlantSelection(plant['id'], plant['commonName']),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                plant['imageUrl'] ?? 'https://via.placeholder.com/100',
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.spa, color: Colors.green),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          plant['commonName'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.green : Colors.black87,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
  
  // Widget for search results in list format
  Widget _buildSearchResultsList() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: 150,
        maxWidth: MediaQuery.of(context).size.width,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final plant = _searchResults[index];
          final bool isSelected = _selectedPlantId == plant['id'];
          
          return ListTile(
            leading: Stack(
              alignment: Alignment.center,
              children: [
                plant['imageUrl'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          plant['imageUrl']!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                        ),
                      )
                    : const Icon(Icons.spa),
                if (isSelected)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
            title: Text(
              plant['commonName'],
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green : Colors.black87,
              ),
            ),
            onTap: () => _togglePlantSelection(plant['id'], plant['commonName']),
            tileColor: isSelected ? Colors.green.withOpacity(0.1) : null,
          );
        },
      ),
    );
  }
} 