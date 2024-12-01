import 'dart:io';
import 'dart:convert'; // Importar para manejar el JSON
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(cameras: cameras),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomeScreen({required this.cameras});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  File? _imageFile;
    File? _processedImageFile;
  bool _isLoading = false;
  String? _prediction;

  final String serverUrl = "http://34.134.217.218:8080/predict";

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _initCamera(widget.cameras.first);
    }
  }

  void _initCamera(CameraDescription camera) {
    _cameraController = CameraController(camera, ResolutionPreset.medium);
    _cameraController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _captureImage() async {
    if (!_cameraController!.value.isInitialized) return;
    final image = await _cameraController!.takePicture();
    setState(() {
      _imageFile = File(image.path);
    });
    _predictImage(File(image.path));
    _showImageDialog();
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _predictImage(File(pickedFile.path));
      _showImageDialog();
    }
  }


Future<void> _predictImage(File image) async {
  setState(() {
    _isLoading = true;
    _prediction = null; // Limpiar la predicción anterior
            _processedImageFile = null;
  });

  final request = http.MultipartRequest('POST', Uri.parse(serverUrl));
  request.files.add(await http.MultipartFile.fromPath('file', image.path));

  try {
    final response = await request.send();

    // Verificar el estado de la respuesta
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();

      // Convertir el JSON a un mapa
      final Map<String, dynamic> jsonResponse = jsonDecode(responseData);
 // setState(() {
      final prediction = jsonResponse['prediction'];

          // Decodificar la imagen en Base64
          final base64Image = jsonResponse['image'];
          final decodedBytes = base64Decode(base64Image);
          final processedImagePath = '${Directory.systemTemp.path}/processed_image.jpg';

          // Guardar la imagen procesada localmente
          File(processedImagePath).writeAsBytesSync(decodedBytes);
          _processedImageFile = File(processedImagePath);
        // });

      // Actualizar el estado con la predicción
      if (mounted) {
        setState(() {
          _prediction = 'La papa capturada pertenece a la variedad $prediction'; // Asumiendo que 'prediction' es un número
          _imageFile = _processedImageFile;
        });
              Navigator.of(context).pop(); // Cierra el cuadro de diálogo una vez se recibe la predicción
        _showImageDialog(); // Vuelve a mostrar el diálogo con la predicción
        }
    } else {
      // Manejo de error en la respuesta
      if (mounted) {
        setState(() {
          _prediction = "Error: ${response.reasonPhrase}";
        });
      }
    }
  } catch (e) {
    // Manejo de errores durante la petición
    if (mounted) {
      setState(() {
        _prediction = "Error al enviar la imagen: $e";
      });
    }
  } finally {
    // Asegurarse de que siempre se detenga el cargando
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}


void _showImageDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_imageFile != null) ...[
                Container(
                  width: 300,  // Ancho fijo
                  height: 400, // Alto fijo
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),  // Bordes redondeados
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),  // Color de la sombra
                        spreadRadius: 5,  // Qué tan lejos se extiende la sombra
                        blurRadius: 10,    // Qué tan difusa es la sombra
                        offset: Offset(0, 5),  // Desplazamiento de la sombra (horizontal, vertical)
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),  // Bordes redondeados
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,  // Ajuste de la imagen dentro del contenedor
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            if (_isLoading) CircularProgressIndicator(),
            if (_prediction != null) ...[
              const SizedBox(height: 10),
              Text(
                _prediction!,
                                        textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Cierra el cuadro de diálogo
                },
                child: Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Variedades de Papa'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cámara
            if (_cameraController != null && _cameraController!.value.isInitialized)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Container(
                  width: 300,  // Ancho fijo
                  height: 400, // Alto fijo
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),  // Bordes redondeados
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),  // Color de la sombra con opacidad
                        spreadRadius: 7,  // Qué tan lejos se extiende la sombra
                        blurRadius: 10,    // Qué tan difusa es la sombra
                        offset: Offset(0, 2),  // Desplazamiento de la sombra (horizontal, vertical)
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),  // Bordes redondeados
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            // Botones
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _captureImage,
                  child: Text('Capturar PAPA'),
                ),
                ElevatedButton(
                  onPressed: _pickImageFromGallery,
                  child: Text('Subir Imagen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
