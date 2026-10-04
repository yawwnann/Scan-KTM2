import 'package:flutter/material.dart';

class ManualInputDialog extends StatefulWidget {
  final Function(String inputValue, String inputType) onSubmit;

  const ManualInputDialog({super.key, required this.onSubmit});

  @override
  State<ManualInputDialog> createState() => _ManualInputDialogState();
}

class _ManualInputDialogState extends State<ManualInputDialog> {
  String inputValue = '';
  String inputType = 'NIM';
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Input Manual'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'NIM', label: Text('NIM')),
                ButtonSegment<String>(value: 'Plat', label: Text('Nomor Plat')),
              ],
              selected: {inputType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  inputType = newSelection.first;
                  inputValue = '';
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              autofocus: true,
              keyboardType: inputType == 'NIM'
                  ? TextInputType.number
                  : TextInputType.text,
              maxLength: inputType == 'NIM' ? 10 : null,
              textCapitalization: inputType == 'NIM'
                  ? TextCapitalization.none
                  : TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: inputType == 'NIM'
                    ? 'Masukkan NIM'
                    : 'Masukkan Nomor Plat',
                hintText: inputType == 'NIM'
                    ? 'Contoh: 2021001234'
                    : 'Contoh: AB 1234 CD',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    inputType == 'NIM'
                        ? Icons.badge_outlined
                        : Icons.directions_car_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                inputValue = inputType == 'NIM'
                    ? value.trim()
                    : value.toUpperCase().trim();
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  widget.onSubmit(inputValue, inputType);
                }
              },
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) {
                  return inputType == 'NIM'
                      ? 'NIM tidak boleh kosong'
                      : 'Nomor plat tidak boleh kosong';
                }
                if (inputType == 'NIM' && v.length != 10) {
                  return 'NIM harus 10 digit';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop();
              widget.onSubmit(inputValue, inputType);
            }
          },
          icon: const Icon(Icons.search, size: 20),
          label: const Text('Cari'),
        ),
      ],
    );
  }
}
