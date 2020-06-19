import 'package:acs_upb_mobile/authentication/service/auth_provider.dart';
import 'package:acs_upb_mobile/generated/l10n.dart';
import 'package:acs_upb_mobile/pages/classes/model/class.dart';
import 'package:acs_upb_mobile/pages/classes/service/class_provider.dart';
import 'package:acs_upb_mobile/widgets/scaffold.dart';
import 'package:acs_upb_mobile/widgets/spoiler.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClassesPage extends StatefulWidget {
  @override
  _ClassesPageState createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  Future<List<String>> userClassIdsFuture;
  Future<List<Class>> classesFuture;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    ClassProvider classProvider = Provider.of<ClassProvider>(context, listen: false);
    AuthProvider authProvider = Provider.of<AuthProvider>(context, listen: false);
    userClassIdsFuture = classProvider.fetchUserClassIds(
        uid: authProvider.uid, context: context);
  }

  @override
  Widget build(BuildContext context) {
    ClassProvider classProvider = Provider.of<ClassProvider>(context);
    AuthProvider authProvider = Provider.of<AuthProvider>(context);

    if (classesFuture == null) {
      classesFuture = classProvider.fetchClasses(uid: authProvider.uid);
    }

    return AppScaffold(
      title: S.of(context).navigationClasses,
      actions: [
        AppScaffoldAction(
          icon: Icons.add,
          tooltip: S.of(context).actionAddClasses,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                  value: classProvider,
                  child: FutureBuilder(
                    future: userClassIdsFuture,
                    builder: (context, snap) {
                      if (snap.hasData) {
                        return AddClassesPage(
                            initialClassIds: snap.data,
                            onSave: (classIds) async {
                              await classProvider.setUserClassIds(
                                  classIds: classIds, uid: authProvider.uid);
                              classesFuture = null;
                              Navigator.pop(context);
                            });
                      } else {
                        return Center(child: CircularProgressIndicator());
                      }
                    },
                  )),
            ),
          ),
        ),
      ],
      body: ClassList(
          classesFuture: classesFuture),
    );
  }
}

class AddClassesPage extends StatefulWidget {
  final List<String> initialClassIds;
  final Function(List<String>) onSave;

  const AddClassesPage({Key key, this.initialClassIds, this.onSave})
      : super(key: key);

  @override
  _AddClassesPageState createState() =>
      _AddClassesPageState(classIds: initialClassIds);
}

class _AddClassesPageState extends State<AddClassesPage> {
  List<String> classIds;
  Future<List<Class>> classesFuture;

  _AddClassesPageState({List<String> classIds})
      : this.classIds = classIds ?? [];

  @override
  Widget build(BuildContext context) {
    if (classesFuture == null) {
      ClassProvider classProvider = Provider.of<ClassProvider>(context);
      classesFuture = classProvider.fetchClasses();
    }

    return AppScaffold(
      title: S.of(context).actionAddClasses,
      actions: [
        AppScaffoldAction(
          text: S.of(context).buttonSave,
          onPressed: () => widget.onSave(classIds),
        )
      ],
      body: ClassList(
        classesFuture: classesFuture,
        initiallySelected: classIds,
        selectable: true,
        onSelected: (selected, classId) {
          if (selected) {
            classIds.add(classId);
          } else {
            classIds.remove(classId);
          }
        },
      ),
    );
  }
}

class ClassList extends StatelessWidget {
  final Future<List<Class>> classesFuture;
  final Function(bool, String) onSelected;
  final List<String> initiallySelected;
  final bool selectable;

  ClassList(
      {this.classesFuture,
      Function(bool, String) onSelected,
      List<String> initiallySelected,
      this.selectable = false})
      : onSelected = onSelected ?? ((selected, classId) {}),
        initiallySelected = initiallySelected ?? [];

  String sectionName(BuildContext context, String year, String semester) =>
      S.of(context).labelYear +
      ' ' +
      year +
      ', ' +
      S.of(context).labelSemester +
      ' ' +
      semester;

  Map<String, List<Class>> sections(List<Class> classes, BuildContext context) {
    Map<String, List<Class>> classSections = {};
    for (var year in ['1', '2', '3', '4']) {
      for (var semester in ['1', '2']) {
        classSections[sectionName(context, year, semester)] = [];
      }
    }
    classes.forEach((c) {
      classSections[sectionName(context, c.year, c.semester)].add(c);
    });
    classSections.keys.forEach(
        (key) => classSections[key].sort((a, b) => a.name.compareTo(b.name)));
    classSections.removeWhere((key, classes) => classes.length == 0);
    return classSections;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: classesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.done) {
            List<Class> classes = snap.data ?? [];
            // TODO: Add special page is user has no classes yet
            var classSections = sections(classes, context);

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                children: classSections
                    .map((sectionName, classes) => MapEntry(
                        sectionName,
                        Column(
                          children: [
                            AppSpoiler(
                              title: sectionName,
                              content: Column(
                                children: <Widget>[Divider()] +
                                    classes
                                        .map<Widget>(
                                          (c) => Column(
                                            children: [
                                              ClassListItem(
                                                selectable: selectable,
                                                initiallySelected:
                                                    initiallySelected
                                                        .contains(c.id),
                                                classInfo: c,
                                                onSelected: (selected) =>
                                                    onSelected(selected, c.id),
                                              ),
                                              Divider(),
                                            ],
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                            SizedBox(height: 8),
                          ],
                        )))
                    .values
                    .toList(),
              ),
            );
          } else if (snap.hasError) {
            print(snap.error);
            // TODO: Show error toast
            return Container();
          } else {
            return Center(child: CircularProgressIndicator());
          }
        });
  }
}

class ClassListItem extends StatefulWidget {
  final Class classInfo;
  final bool initiallySelected;
  final Function(bool) onSelected;
  final bool selectable;

  ClassListItem(
      {Key key,
      this.classInfo,
      this.initiallySelected = false,
      Function(bool) onSelected,
      this.selectable = false})
      : this.onSelected = onSelected ?? ((_) {}),
        super(key: key);

  @override
  _ClassListItemState createState() =>
      _ClassListItemState(selected: initiallySelected);
}

class _ClassListItemState extends State<ClassListItem> {
  bool selected;

  _ClassListItemState({this.selected});

  Color colorFromAcronym(String acronym) {
    int r = 0, g = 0, b = 0;
    if (acronym.length >= 1) {
      b = acronym[0].codeUnitAt(0);
      if (acronym.length >= 2) {
        g = acronym[1].codeUnitAt(0);
        if (acronym.length >= 3) {
          r = acronym[2].codeUnitAt(0);
        }
      }
    }
    int brightnessFactor = 2;
    return Color.fromRGBO(
        r * brightnessFactor, g * brightnessFactor, b * brightnessFactor, 1);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorFromAcronym(widget.classInfo.acronym),
        child: (widget.selectable && selected)
            ? Icon(Icons.check)
            : AutoSizeText(
                widget.classInfo.acronym,
                minFontSize: 5,
                maxLines: 1,
              ),
      ),
      title: Text(
        widget.classInfo.name +
            (widget.classInfo.series == null
                ? ''
                : ' (' + widget.classInfo.series + ')'),
        style: widget.selectable
            ? (selected
                ? Theme.of(context)
                    .textTheme
                    .subtitle1
                    .copyWith(fontWeight: FontWeight.bold)
                : TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontWeight: FontWeight.normal))
            : Theme.of(context).textTheme.subtitle1,
      ),
      onTap: () => setState(() {
        selected = !selected;
        widget.onSelected(selected);
      }),
    );
  }
}