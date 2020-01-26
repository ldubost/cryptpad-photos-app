import 'dart:async';
import 'package:cryptpad_photos_app/main.dart';
import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';
import 'package:cryptpad_photos_app/main.dart';

class PreferencesPage extends StatefulWidget {
  PreferencesPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _PreferencePageState createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: PreferencePage([
          PreferenceTitle('CryptPad Instance'),
          TextFieldPreference('Server', 'server',
              defaultVal: "https://cryptpad.fr", onChange: (String value) {
            print("Set server " + value);
            PrefService.setString("server", value);
            MyHomePageState.setCryptPadInstanceURL(
                PrefService.getString("server"));
          }),
          PreferenceTitle('Synchronization'),
          SwitchPreference(
            'Automatic Sync',
            'autosync',
            defaultVal: false,
            onEnable: () {
              print("Enable autosync");
              PrefService.setBool('autosync', true);
              MyHomePageState.setAutoSync(true);
            },
            onDisable: () {
              print("Disable autosync");
              PrefService.setBool('autosync', false);
              MyHomePageState.setAutoSync(false);
            },
          ),
          SwitchPreference(
            'Sync Videos',
            'syncvideos',
            defaultVal: false,
            onEnable: () {
              print("Enable sync videos");
              PrefService.setBool('syncvideos', true);
              MyHomePageState.setSyncVideos(true);
            },
            onDisable: () {
              print("Disable sync videos");
              PrefService.setBool('syncvideos', false);
              MyHomePageState.setSyncVideos(false);
            },
          ),
          SwitchPreference(
            'Sync on Wifi only',
            'autosyncwifionly',
            defaultVal: true,
            onEnable: () {
              print("Enable autosyncwifionly");
              PrefService.setBool('autosyncwifionly', true);
              MyHomePageState.setAutoSyncWifiOnly(true);
            },
            onDisable: () {
              print("Disable autosyncwifionly");
              PrefService.setBool('autosyncwifionly', false);
              MyHomePageState.setAutoSyncWifiOnly(false);
            },
          ),
          TextFieldPreference('Max number of days', 'maxdays', defaultVal: '10',
              onChange: (String value) {
            print("Set maxdays " + value);
            PrefService.setString('maxdays', value);
            MyHomePageState.setMaxDays(int.parse(value));
          }),
          PreferenceTitle('Start Page'),
          DropdownPreference('Start Page', 'startpage',
              defaultVal: 'Default',
              values: ['Default', 'Local Images', 'Remote Images'],
              onChange: (String value) {
            print("Set maxdays " + value);
            // PrefService.setString('startpage', value);
          }),
        ]));
  }
}
