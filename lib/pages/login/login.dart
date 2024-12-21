import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tsyproject/pages/home/home.dart';
import 'package:tsyproject/pages/signup/signup.dart';

class LoginForm extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _Login();
  }
}

class _Login extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login Form"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _emailController,
              validator: (val) {
                if (val == null || val.isEmpty) return "Please enter email";
                return null;
              },
              decoration: InputDecoration(
                labelText: "Enter Email",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            TextFormField(
              controller: _passwordController,
              validator: (val) {
                if (val == null || val.isEmpty) return "Please enter password";
                return null;
              },
              decoration: InputDecoration(
                labelText: "Enter Password",
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    print("Attempting login for: ${_emailController.text}");
                    UserCredential userCredential =
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                    print('User ID: ${userCredential.user?.uid}');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyHome(),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    print("FirebaseAuthException: ${e.code}");
                    String errorMessage = 'Authentication failed';
                    if (e.code == 'user-not-found') {
                      errorMessage = 'No user found for that email.';
                    } else if (e.code == 'wrong-password') {
                      errorMessage = 'Wrong password provided for that user.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                      ),
                    );
                  } catch (e) {
                    print("Unexpected error: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'An unexpected error occurred. Please try again.'),
                      ),
                    );
                  }
                }
              },
              child: Text("Login"),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account? "),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignupForm(),
                      ),
                    );
                  },
                  child: Text("Sign Up"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
