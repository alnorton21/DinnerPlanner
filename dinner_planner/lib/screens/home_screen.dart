import 'package:flutter/material.dart';
import 'add_meal_screen.dart';
import 'meal_list_screen.dart'; // we’ll create this next

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dinner Planner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.list),
              label: Text('View Meals'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MealListScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Add Meal'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddMealScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.calendar_today),
              label: Text('Meal Planner'),
              onPressed: () {
                // TODO: Add Meal Planner screen later
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Coming soon!')),
                );
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}