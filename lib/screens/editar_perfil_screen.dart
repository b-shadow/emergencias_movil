import 'package:flutter/material.dart';
import '../services/cliente_service.dart';
import '../widgets/theme_toggle_button.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({Key? key}) : super(key: key);

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final ClienteService _clienteService = ClienteService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _correoController;
  late TextEditingController _telefonoController;
  late TextEditingController _ciController;
  late TextEditingController _direccionController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _apellidoController = TextEditingController();
    _correoController = TextEditingController();
    _telefonoController = TextEditingController();
    _ciController = TextEditingController();
    _direccionController = TextEditingController();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final perfil = await _clienteService.getMiPerfil();
      setState(() {
        _nombreController.text = perfil.nombre;
        _apellidoController.text = perfil.apellido;
        _correoController.text = perfil.correo;
        _telefonoController.text = perfil.telefono ?? '';
        _ciController.text = perfil.ci ?? '';
        _direccionController.text = perfil.direccion ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar perfil: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _clienteService.actualizarPerfil(
        nombre: _nombreController.text,
        apellido: _apellidoController.text,
        telefono: _telefonoController.text,
        ci: _ciController.text,
        direccion: _direccionController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Perfil actualizado correctamente',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF40C057),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _ciController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1117) : const Color(0xFFF6F7FB);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('Editar Mi Perfil'),
          backgroundColor: const Color(0xFF6B46C1),
          foregroundColor: Colors.white,
          actions: const [ThemeToggleButton()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('Editar Mi Perfil'),
          backgroundColor: const Color(0xFF6B46C1),
          foregroundColor: Colors.white,
          actions: const [ThemeToggleButton()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cargarPerfil,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Editar Mi Perfil'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        actions: const [ThemeToggleButton()],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            children: [
              _buildInputCard(
                icon: Icons.person,
                label: 'Nombre *',
                controller: _nombreController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.person_outline,
                label: 'Apellido *',
                controller: _apellidoController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El apellido es requerido';
                  }
                  if (value.length < 2) {
                    return 'El apellido debe tener al menos 2 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.email_outlined,
                label: 'Correo',
                controller: _correoController,
                readOnly: true,
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.phone_outlined,
                label: 'Teléfono',
                hintText: 'Ej: +591 1234567',
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.badge_outlined,
                label: 'Cédula de Identidad',
                hintText: 'Ej: 1234567',
                controller: _ciController,
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.location_on_outlined,
                label: 'Dirección',
                hintText: 'Ej: Calle Principal 123, Apto 4',
                controller: _direccionController,
                maxLines: 2,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarCambios,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B46C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
