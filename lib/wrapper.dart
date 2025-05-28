// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_card_app_passenger/auth_interfaces/authentication.dart';
import 'package:smart_card_app_passenger/manage_interfaces/home_screen.dart';
import 'package:smart_card_app_passenger/models/passenger.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<Passenger?>(context);

    if (user != null) {
      return HomeScreen();
    }else{
      return Authentication();
    }
  }
}
