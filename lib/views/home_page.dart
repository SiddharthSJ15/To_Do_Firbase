import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:to_do/views/login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Get the current user from Firebase Auth
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // You might want to add a check here to ensure currentUser is not null
    // and potentially redirect to login if it is, though your main.dart
    // or wrapper might handle this.
  }

  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController();
  // No need for editId as a class member if it's passed directly to functions

  // Helper function to get card color based on priority and status
  Color _getCardColor(String priority, String status) {
    if (status == 'completed') {
      return Colors.grey.shade100; // Light grey for completed tasks
    }
    
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade50;
      case 'medium':
        return Colors.orange.shade50;
      case 'low':
        return Colors.green.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  // Helper function to get border color based on priority and status
  Color _getBorderColor(String priority, String status) {
    if (status == 'completed') {
      return Colors.grey.shade400; // Darker grey border for completed tasks
    }
    
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade300;
      case 'medium':
        return Colors.orange.shade300;
      case 'low':
        return Colors.green.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  void taskManagement(String? editId, {Map<String, dynamic>? initialData}) {
    final _formKey = GlobalKey<FormState>();

    if (initialData != null) {
      _taskController.text = initialData['task'] ?? '';
      _dateController.text = initialData['dueDate'] ?? '';
      _priorityController.text = initialData['priority'] ?? '';
    } else {
      _taskController.clear();
      _dateController.clear();
      _priorityController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('To-Do List'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Task',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null) {
                        _dateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(pickedDate);
                      }
                    },
                    controller: _dateController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Date',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _priorityController.text.isEmpty
                        ? null
                        : _priorityController.text,
                    items: ['low', 'medium', 'high']
                        .map(
                          (priority) => DropdownMenuItem<String>(
                            value: priority,
                            child: Text(priority.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _priorityController.text = value ?? '';
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Priority',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _submit(editId);
                _taskController.clear();
                _dateController.clear();
                _priorityController.clear();
                Navigator.of(context).pop();
              },
              child: editId != null
                  ? const Text('Update')
                  : const Text('Submit'),
            ),
            TextButton(
              onPressed: () {
                _taskController.clear();
                _dateController.clear();
                _priorityController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleStatus(String taskId, String currentStatus) async {
    final newStatus = currentStatus == 'pending' ? 'completed' : 'pending';
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'status': newStatus,
    });
  }

  Future<void> _submit(String? editId) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in. Please log in.')),
      );
      return;
    }

    if (_taskController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _priorityController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final String userId = currentUser!.uid;

    if (editId != null) {
      await FirebaseFirestore.instance.collection('tasks').doc(editId).update({
        'task': _taskController.text,
        'dueDate': _dateController.text,
        'priority': _priorityController.text,
      });
    } else {
      await FirebaseFirestore.instance.collection('tasks').add({
        'task': _taskController.text,
        'dueDate': _dateController.text,
        'status': 'pending',
        'priority': _priorityController.text,
        'userId': userId,
      });
    }
  }

  void _delete(String? taskId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(taskId)
                    .delete();
                if (mounted) {
                  // Check if the widget is still mounted before popping
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If currentUser is null, you might want to show a loading indicator
    // or navigate to the login screen directly here.
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(), // Or a message like "Please log in"
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        actionsPadding: const EdgeInsets.only(right: 12.0),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tasks')
                    .where(
                      'userId',
                      isEqualTo: currentUser!.uid,
                    ) // Filter by current user's UID
                    .orderBy('dueDate', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No tasks available.'));
                  }
                  final tasks = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final priority = task['priority'] ?? 'low';
                      final status = task['status'] ?? 'pending';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 2,
                        ),
                        elevation: 2,
                        color: _getCardColor(priority, status),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _getBorderColor(priority, status),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          leading: GestureDetector(
                            onTap: () => _toggleStatus(task.id, task['status']),
                            child: Icon(
                              task['status'] == 'completed'
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: task['status'] == 'completed'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          title: Text(
                            task['task'],
                            style: TextStyle(
                              decoration: task['status'] == 'completed'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Due: ${task['dueDate']}'),
                              Text(
                                'Priority: ${task['priority'].toUpperCase()}',
                                style: TextStyle(
                                  color: _getBorderColor(priority, status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                tooltip: 'Edit',
                                onPressed: () {
                                  taskManagement(
                                    task.id,
                                    initialData:
                                        task.data() as Map<String, dynamic>,
                                  ); // Pass initial data
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete',
                                onPressed: () => _delete(task.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            taskManagement(null), // Call without initial data for new task
        child: const Icon(Icons.add),
      ),
    );
  }
}