import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenPage extends StatefulWidget {
  const TokenPage({super.key});

  @override
  State<TokenPage> createState() => _TokenPageState();
}

class _TokenPageState extends State<TokenPage> {
  final _formKey = GlobalKey<FormState>();

  var token_1 = "";
  var token_2 = "";

  var token_validator = (String? value) {
    print(value?.length ?? 0);
    return !(value != null && value.length == 136) ? "Invalid key" : null;
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("2UP Visualiser"),
      ),
      body: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: SizedBox(
            height: 400,
            child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          "Enter your tokens",
                          style: Theme.of(context).textTheme.headline5,
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(
                          height: 40,
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                            label: Text("Token 1"),
                            hintText: "up:yeah:....",
                          ),
                          onChanged: (value) => token_1 = value,
                          validator: token_validator,
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                              label: Text("Token 2"), hintText: "up:yeah:...."),
                          onChanged: (value) => token_2 = value,
                          validator: token_validator,
                        ),
                      ],
                    ),
                    OutlinedButton(
                        onPressed: () {
                          var currentState = _formKey.currentState;
                          if (currentState != null) {
                            if (currentState.validate()) {
                              SharedPreferences.getInstance().then((sp) {
                                sp.setString("token1", token_1);
                                sp.setString("token2", token_2);
                              }).catchError((error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Ensure your tokens are correct")));
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Ensure your tokens are correct")));
                            }
                          }
                        },
                        child: const Text("Submit"))
                  ],
                )),
          ),
        ),
      ),
    );
  }
}
