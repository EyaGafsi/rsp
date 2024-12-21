import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tsyproject/pages/login/login.dart';

class SignupForm extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _Signup();
  }
}

class _Signup extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sign Up Form"),
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
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("User created successfully!"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginForm(),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    String errorMessage = 'Sign up failed';
                    if (e.code == 'weak-password') {
                      errorMessage = 'The password provided is too weak.';
                    } else if (e.code == 'email-already-in-use') {
                      errorMessage =
                          'The account already exists for that email.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                      ),
                    );
                  } catch (e) {
                    print(e);
                  }
                }
              },
              child: Text("Sign Up"),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Already have an account? "),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginForm(),
                      ),
                    );
                  },
                  child: Text("Sign In"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
