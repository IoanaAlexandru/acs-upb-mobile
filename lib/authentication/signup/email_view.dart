import 'package:acs_upb_mobile/authentication/signup/password_view.dart';
import 'package:acs_upb_mobile/authentication/signup/sign_up_view.dart';
import 'package:acs_upb_mobile/authentication/utils.dart';
import 'package:acs_upb_mobile/generated/l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailView extends StatefulWidget {
  final bool passwordCheck;
  final FirebaseAuth auth;

  EmailView(this.passwordCheck, this.auth, {Key key}) : super(key: key);

  @override
  _EmailViewState createState() => new _EmailViewState();
}

class _EmailViewState extends State<EmailView> {
  final TextEditingController _controllerEmail = new TextEditingController();

  @override
  Widget build(BuildContext context) => new Scaffold(
        appBar: new AppBar(
          title: new Text(S.of(context).messageWelcomeSimple),
          elevation: 4.0,
        ),
        body: new Builder(
          builder: (BuildContext context) {
            return new Padding(
              padding: const EdgeInsets.all(16.0),
              child: new Column(
                children: <Widget>[
                  new TextField(
                    controller: _controllerEmail,
                    autofocus: true,
                    onSubmitted: _submit,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: new InputDecoration(
                        labelText: S.of(context).labelEmail),
                  ),
                ],
              ),
            );
          },
        ),
        persistentFooterButtons: <Widget>[
          new ButtonBar(
            alignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new FlatButton(
                  onPressed: () => _connect(context),
                  child: new Row(
                    children: <Widget>[
                      new Text(S.of(context).buttonNext),
                    ],
                  )),
            ],
          )
        ],
      );

  _submit(String submitted) {
    _connect(context);
  }

  _connect(BuildContext context) async {
    try {
      final FirebaseAuth auth = widget.auth;
      List<String> providers =
          await auth.fetchSignInMethodsForEmail(email: _controllerEmail.text);
      print(providers);

      if (providers == null || providers.isEmpty) {
        bool connected = await Navigator.of(context)
            .push(new MaterialPageRoute<bool>(builder: (BuildContext context) {
          return new SignUpView(
              _controllerEmail.text, widget.passwordCheck, auth);
        }));

        if (connected) {
          Navigator.pop(context);
        }
      } else if (providers.contains('password')) {
        bool connected = await Navigator.of(context)
            .push(new MaterialPageRoute<bool>(builder: (BuildContext context) {
          return new PasswordView(_controllerEmail.text, auth);
        }));

        if (connected) {
          Navigator.pop(context);
        }
      } else {
        String provider = await _showDialogSelectOtherProvider(
            _controllerEmail.text, providers);
        if (provider.isNotEmpty) {
          Navigator.pop(context, provider);
        }
      }
    } catch (exception) {
      await showErrorDialog(
          context,
          S.of(context).errorSomethingWentWrong +
              " " +
              S.of(context).warningInternetConnection);
      print(exception);
    }
  }

  _showDialogSelectOtherProvider(String email, List<String> providers) {
    var providerName = _providersToString(providers);
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) => new AlertDialog(
        content: new SingleChildScrollView(
            child: new ListBody(
          children: <Widget>[
            new Text(S.of(context).warningEmailInUse(email) + ' ' + S.of(context).warningUseProvider(providerName)),
            new SizedBox(
              height: 16.0,
            ),
            new Column(
              children: providers.map((String p) {
                return new RaisedButton(
                  child: new Row(
                    children: <Widget>[
                      new Text(_providerStringToButton(p)),
                    ],
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(p);
                  },
                );
              }).toList(),
            )
          ],
        )),
        actions: <Widget>[
          new FlatButton(
            child: new Row(
              children: <Widget>[
                new Text(S.of(context).buttonCancel),
              ],
            ),
            onPressed: () {
              Navigator.of(context).pop('');
            },
          ),
        ],
      ),
    );
  }

  String _providersToString(List<String> providers) {
    return providers.map((String provider) {
      ProvidersTypes type = stringToProvidersType(provider);
      return providersDefinitions(context)[type]?.name;
    }).join(", ");
  }

  String _providerStringToButton(String provider) {
    ProvidersTypes type = stringToProvidersType(provider);
    return providersDefinitions(context)[type]?.label;
  }
}
