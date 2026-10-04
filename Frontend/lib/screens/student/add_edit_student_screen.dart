import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/faculty_data.dart';
import '../../services/api_service.dart';
import '../../services/ocr_service.dart';
import '../../utils/logging/logger.dart';
import '../../config/app_config.dart';
import '../../data/demo_data.dart';

class AddEditStudentScreen extends StatefulWidget {
  final Student? student;
  final String? initialBarcode;
  final String? scanMethod;
  final OCRResult? ocrResult;

  const AddEditStudentScreen({
    super.key,
    this.student,
    this.initialBarcode,
    this.scanMethod,
    this.ocrResult,
  });

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nimController = TextEditingController();
  final _nameController = TextEditingController();
  final _facultyController = TextEditingController();
  final _studyProgramController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehicleBrandController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.student != null;

    if (_isEditMode) {
      // Mode edit - isi dengan data mahasiswa yang ada
      _nimController.text = widget.student!.nim;
      _nameController.text = widget.student!.name;
      _facultyController.text = widget.student!.faculty;
      _studyProgramController.text = widget.student!.studyProgram;
      _vehicleNumberController.text = widget.student!.vehicleNumber;
      _vehicleTypeController.text = widget.student!.vehicleType;
      _vehicleBrandController.text = widget.student!.vehicleBrand;
    } else if (widget.ocrResult != null) {
      // Mode tambah dengan data OCR - isi otomatis dari hasil OCR
      _nimController.text = widget.ocrResult!.nim ?? '';
      _nameController.text = widget.ocrResult!.name ?? '';
      _facultyController.text = widget.ocrResult!.faculty ?? '';
      _studyProgramController.text = widget.ocrResult!.studyProgram ?? '';
      // Nomor kendaraan dari OCR (jika ada) atau kosong untuk diisi manual
      _vehicleNumberController.text = widget.ocrResult!.vehicleNumber ?? '';
      // Jenis kendaraan default kosong, harus diisi manual
      _vehicleTypeController.text = '';
      _vehicleBrandController.text = '';
    } else if (widget.initialBarcode != null) {
      // Mode tambah dengan barcode saja
      _nimController.text = widget.initialBarcode!;
    }
  }

  @override
  void dispose() {
    _nimController.dispose();
    _nameController.dispose();
    _facultyController.dispose();
    _studyProgramController.dispose();
    _vehicleNumberController.dispose();
    _vehicleTypeController.dispose();
    _vehicleBrandController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final student = Student.create(
        nim: _nimController.text.trim(),
        name: _nameController.text.trim(),
        faculty: _facultyController.text.trim(),
        studyProgram: _studyProgramController.text.trim(),
        vehicleNumber: _vehicleNumberController.text.trim(),
        vehicleType: _vehicleTypeController.text.trim(),
        vehicleBrand: _vehicleBrandController.text.trim(),
      );

      bool success;
      if (AppConfig.isDevelopment) {
        if (_isEditMode) {
          DemoData.updateStudent(widget.student!.nim, student);
        } else {
          DemoData.addStudent(student);
        }
        success = true;
      } else {
        if (_isEditMode) {
          success = await ApiService.updateStudent(student);
        } else {
          success = await ApiService.createStudent(student);
        }
      }

      if (!mounted) return;

      if (success) {
        final successMessage = _isEditMode
            ? 'Mahasiswa berhasil diupdate'
            : 'Mahasiswa berhasil ditambahkan';
        _showCustomSnackBar(
          message: successMessage,
          icon: Icons.check_circle,
          backgroundColor: Colors.green,
        );
        Navigator.of(context).pop(student);
      } else {
        _showCustomSnackBar(
          message: 'Gagal menyimpan data mahasiswa',
          icon: Icons.error,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      Logger.error('Error saving student: $e');
      if (mounted) {
        _showCustomSnackBar(
          message: 'Terjadi kesalahan: $e',
          icon: Icons.warning,
          backgroundColor: Colors.orange,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    title == 'Data Pribadi'
                        ? Icons.person
                        : Icons.directions_car,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _getBaseInputDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool enabled = true,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final lightGrey = Colors.grey.shade300;
    final lighterGrey = Colors.grey.shade200;

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled
              ? primaryColor.withAlpha((255 * 0.1).round())
              : Colors.grey.withAlpha((255 * 0.1).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          prefixIcon,
          color: enabled ? primaryColor : Colors.grey,
          size: 20,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lighterGrey),
      ),
      filled: true,
      fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    bool enabled = true,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: _getBaseInputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        enabled: enabled,
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: controller.text.isEmpty || !items.contains(controller.text)
          ? null
          : controller.text,
      decoration:
          _getBaseInputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: prefixIcon,
          ).copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      dropdownColor: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(
          _isEditMode ? 'Edit Mahasiswa' : 'Tambah Mahasiswa',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (widget.ocrResult != null && !_isEditMode)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha((255 * 0.3).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'OCR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header dengan informasi
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.ocrResult != null && !_isEditMode
                            ? Colors.green[50]
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.ocrResult != null && !_isEditMode
                              ? Colors.green[200]!
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.ocrResult != null && !_isEditMode
                                ? Icons.auto_awesome
                                : Icons.info_outline,
                            color: widget.ocrResult != null && !_isEditMode
                                ? Colors.green[600]
                                : Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isEditMode
                                  ? 'Anda sedang mengedit data mahasiswa. NIM tidak dapat diubah.'
                                  : widget.ocrResult != null
                                  ? 'Data telah diisi otomatis dari hasil OCR. Periksa dan lengkapi data yang masih kosong, terutama nomor plat kendaraan.'
                                  : 'Lengkapi semua data yang diperlukan dengan benar.',
                              style: TextStyle(
                                color: widget.ocrResult != null && !_isEditMode
                                    ? Colors.green[700]
                                    : Theme.of(context).colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Data Pribadi Section
                    _buildSectionCard('Data Pribadi', [
                      _buildTextFormField(
                        controller: _nimController,
                        labelText: 'NIM *',
                        hintText: 'Masukkan NIM mahasiswa',
                        prefixIcon: Icons.badge_outlined,
                        enabled: !_isEditMode,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'NIM tidak boleh kosong';
                          }
                          if (value.trim().length != 10) {
                            return 'NIM harus 10 digit';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      _buildTextFormField(
                        controller: _nameController,
                        labelText: 'Nama Lengkap *',
                        hintText: 'Masukkan nama lengkap mahasiswa',
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      _buildDropdownField(
                        controller: _facultyController,
                        labelText: 'Fakultas *',
                        hintText: 'Pilih fakultas',
                        prefixIcon: Icons.school_outlined,
                        items: FacultyData.getFaculties(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _facultyController.text = newValue ?? '';
                            // Jika fakultas berubah dan program studi tidak sesuai, kosongkan
                            if (_facultyController.text.isNotEmpty) {
                              final availablePrograms =
                                  FacultyData.getAllStudyPrograms(
                                    _facultyController.text,
                                  );
                              if (!availablePrograms.contains(
                                _studyProgramController.text,
                              )) {
                                _studyProgramController.clear();
                              }
                            } else {
                              _studyProgramController.clear();
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Fakultas tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      _buildDropdownField(
                        controller: _studyProgramController,
                        labelText: 'Program Studi *',
                        hintText: _facultyController.text.isEmpty
                            ? 'Pilih fakultas dulu'
                            : 'Pilih program studi',
                        prefixIcon: Icons.book_outlined,
                        items: _facultyController.text.isEmpty
                            ? []
                            : FacultyData.getAllStudyPrograms(
                                _facultyController.text,
                              ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _studyProgramController.text = newValue ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Program studi tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                    ]),
                    SizedBox(height: 20),

                    // Data Kendaraan Section
                    _buildSectionCard('Data Kendaraan', [
                      _buildTextFormField(
                        controller: _vehicleNumberController,
                        labelText: 'Nomor Plat Kendaraan *',
                        hintText: 'Contoh: AB 1234 CD',
                        prefixIcon: Icons.directions_car_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nomor plat tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      _buildDropdownField(
                        controller: _vehicleTypeController,
                        labelText: 'Jenis Kendaraan *',
                        hintText: 'Pilih jenis kendaraan',
                        prefixIcon: Icons.two_wheeler_outlined,
                        items: const ['Motor', 'Mobil'],
                        onChanged: (String? newValue) {
                          setState(() {
                            _vehicleTypeController.text = newValue ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jenis kendaraan tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      _buildTextFormField(
                        controller: _vehicleBrandController,
                        labelText: 'Merk Kendaraan (Opsional)',
                        hintText: 'Contoh: Vario, Beat, Avanza, dll.',
                        prefixIcon: Icons.directions_car_filled_outlined,
                        validator: (value) {
                          // Opsional, jadi tidak wajib
                          return null;
                        },
                      ),
                    ]),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom Save Button
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha((255 * 0.3).round()),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(
                                    (255 * 0.2).round(),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  _isEditMode ? Icons.update : Icons.save,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                _isEditMode ? 'Update Data' : 'Simpan Data',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
