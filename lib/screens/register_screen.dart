import 'dart:developer';

import 'package:appointment_app/myWidgets/input_field_widget.dart';
import 'package:appointment_app/myWidgets/line_widget.dart';
import 'package:appointment_app/styles/app_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../myWidgets/dropdown_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String? selectedRole;
  var roleList = ['As a Doctor', 'As a Receptionist'];

  var fnameController = TextEditingController();
  var lnameController = TextEditingController();
  var emailController = TextEditingController();
  var setPasswordController = TextEditingController();
  // var phonenoController = TextEditingController();

  String fname = "",lname = "", email = "", setPassword = "", phoneNo = "";
  final _formkey = GlobalKey<FormState>();

  Future<void> registration() async {
    if (selectedRole != null) {
      UserCredential? userCredential;
      try {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: setPassword,
        ).then((value){
          FirebaseFirestore.instance.collection("Users").doc(emailController.text.toString()).set({
            'First Name':fnameController.text.toString(),
            'Last Name':lnameController.text.toString(),
            'Email':emailController.text.toString().trim(),
            'Role':selectedRole.toString(),
          });
          return null;
          // return null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered Successfully.')),
        );
        Navigator.pushNamed(context, 'login_screen');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email already exists. Try again')),
          );
        } else if (e.code == 'wrong-password') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid password. Try again')),
          );
        } else {
          log(e.code.toString());
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unknown Error Occurred')),
      );
    }
  }

  bool _visibility = false; // Declared the pw is not visible (false)
  // when _visibility is false then hideText must be true vice versa. {IMP}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.bgColor,
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(35),
            margin: const EdgeInsets.symmetric(vertical: 20),
            child: Form(
              key: _formkey,
              child: Column(
                children: [
                  // Title
                  Text(
                    "Get Started",
                    style: AppStyles.headLineStyle1
                        .copyWith(color: AppStyles.primary),
                  ),
                  const SizedBox(
                    height: 30,
                  ),

                  // User Input fields
                  InputFieldWidget(defaultHintText: 'Enter First Name', controller: fnameController, requiredInput: 'Name',hideText: false,),
                  const SizedBox(height: 20,),
                  InputFieldWidget(defaultHintText: 'Enter Last Name', controller: lnameController, requiredInput: 'Name',hideText: false,),
                  const SizedBox(height: 20,),
                  InputFieldWidget(
                    defaultHintText: 'Enter Email ID',
                    controller: emailController,
                    requiredInput: 'Email id',
                    suffixIcon: Icon(
                      Icons.email_rounded,
                      color: AppStyles.secondary,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  InputFieldWidget(
                    defaultHintText: 'Enter Password',
                    controller: setPasswordController,
                    requiredInput: 'Password',
                    hideText:
                        !_visibility, // [Not _isPasswordVisible=false]--> (i.e password is visible / (TRUE) )
                    // Now the at last bool
                    suffixIcon: IconButton(
                      icon: Icon(
                        color: AppStyles.secondary,
                        _visibility ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _visibility = !_visibility;
                        });
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  // InputFieldWidget(defaultHintText: 'Phone No.', controller: phonenoController, requiredInput: 'Phone no.',hideText: false,),
                  // const SizedBox(height: 20,),
                  DropdownWidget(
                    itemList: roleList,
                    selectedItem: selectedRole,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedRole = newValue;
                      });
                    },
                    select: 'Select Role',
                  ),
                  const SizedBox(
                    height: 30,
                  ),

                  // Register Button
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      style: AppStyles.buttonStyle,
                      onPressed: () {
                        if (_formkey.currentState!.validate()) {
                          setState(() {
                            fname = fnameController.text.trim();
                            lname = lnameController.text.trim();
                            email = emailController.text.trim();
                            setPassword = setPasswordController.text.trim();
                            // phoneNo = phonenoController.text;
                          });
                        }
                        registration();
                      },
                      child: Text(
                        'Register',
                        style: AppStyles.headLineStyle3.copyWith(
                          color: Colors.white,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Stack(
                    children: [
                      const LineWidget(),
                      Center(
                        child: Container(
                          color: AppStyles.bgColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2), // Adjust padding as needed
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: AppStyles
                                  .secondary, // Change text color for better visibility
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10,),
                  Column(
                    children: [
                      Text(
                        'Sign up with',
                        style: TextStyle(
                          color: AppStyles.primary,
                        ),
                      ),
                      const SizedBox(height: 20,),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: (){},
                            child: Image.asset(
                              'assets/images/google_logo.png',
                              width: 35,
                              height: 35,
                            ),
                          ),
                          GestureDetector(
                            onTap: (){},
                            child: Image.asset(
                              'assets/images/fb.png',
                              width: 35,
                              height: 35,
                            ),
                          ),
                          GestureDetector(
                            onTap: (){},
                            child: Image.asset(
                              'assets/images/apple_logo.png',
                              width: 40,
                              height: 40,
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 20,),
                      // Already have an account-->  login
                      Container(
                        color: AppStyles.bgColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2), // Adjust padding as needed
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, 'login_screen');
                          },
                          child: Text(
                            'Already have an Account?   LOG IN',
                            style: TextStyle(
                              color: AppStyles
                                  .secondary, // Change text color for better visibility
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
