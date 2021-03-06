import 'dart:async';

import 'package:acs_upb_mobile/authentication/model/user.dart';
import 'package:acs_upb_mobile/generated/l10n.dart';
import 'package:acs_upb_mobile/pages/filter/model/filter.dart';
import 'package:acs_upb_mobile/pages/portal/model/website.dart';
import 'package:acs_upb_mobile/widgets/toast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:preferences/preference_service.dart';

extension UserExtension on User {
  /// Check if there is at least one website that the [user] has permission to edit
  Future<bool> get hasEditableWebsites async {
    // We assume there is at least one public website in the database
    if (canEditPublicWebsite) return true;
    return await hasPrivateWebsites;
  }

  /// Check if user has at least one private website
  Future<bool> get hasPrivateWebsites async {
    CollectionReference ref = Firestore.instance
        .collection('users')
        .document(uid)
        .collection('websites');
    return (await ref.getDocuments()).documents.length > 0;
  }
}

extension WebsiteCategoryExtension on WebsiteCategory {
  static WebsiteCategory fromString(String category) {
    switch (category) {
      case 'learning':
        return WebsiteCategory.learning;
      case 'administrative':
        return WebsiteCategory.administrative;
      case 'association':
        return WebsiteCategory.association;
      case 'resource':
        return WebsiteCategory.resource;
      default:
        return WebsiteCategory.other;
    }
  }
}

extension WebsiteExtension on Website {
  // [ownerUid] should be provided if the website is user-private
  static Website fromSnap(DocumentSnapshot snap, {String ownerUid}) {
    return Website(
      ownerUid: ownerUid ?? snap.data['addedBy'],
      id: snap.documentID,
      isPrivate: ownerUid != null,
      editedBy: List<String>.from(snap.data['editedBy'] ?? []),
      category: WebsiteCategoryExtension.fromString(snap.data['category']),
      iconPath: snap.data['icon'] ?? 'icons/websites/globe.png',
      label: snap.data['label'] ?? 'Website',
      link: snap.data['link'] ?? '',
      infoByLocale: snap.data['info'] == null
          ? {}
          : {
              'en': snap.data['info']['en'],
              'ro': snap.data['info']['ro'],
            },
      degree: snap.data['degree'],
      relevance: snap.data['relevance'] == null
          ? null
          : List<String>.from(snap.data['relevance']),
    );
  }

  Map<String, dynamic> toData() {
    Map<String, dynamic> data = {};

    if (!isPrivate) {
      if (ownerUid != null) data['addedBy'] = ownerUid;
      data['editedBy'] = editedBy;
      data['relevance'] = relevance;
      if (degree != null) data['degree'] = degree;
    }

    if (label != null) data['label'] = label;
    if (category != null)
      data['category'] = category.toString().split('.').last;
    if (iconPath != null) data['icon'] = iconPath;
    if (link != null) data['link'] = link;
    if (infoByLocale != null) data['info'] = infoByLocale;

    return data;
  }
}

class WebsiteProvider with ChangeNotifier {
  final Firestore _db = Firestore.instance;

  void _errorHandler(e, context) {
    print(e.message);
    if (context != null) {
      if (e.message.contains('PERMISSION_DENIED')) {
        AppToast.show(S.of(context).errorPermissionDenied);
      } else {
        AppToast.show(S.of(context).errorSomethingWentWrong);
      }
    }
  }

  /// Initializes the number of visits of websites with the value stored locally.
  ///
  /// Because [PrefService] doesn't support storing maps, the
  /// data is stored in 2 lists: the list of website IDs ([websiteIds]) and the list
  /// with the number of visits ([websiteVisits]), where `websiteVisits[i]` is the
  /// number of times the user accessed website with ID `websiteIds[i]`.
  void initializeNumberOfVisits(List<Website> websites) {
    List<String> websiteIds =
        PrefService.sharedPreferences.getStringList('websiteIds') ?? [];
    List<String> websiteVisits =
        PrefService.sharedPreferences.getStringList('websiteVisits') ?? [];

    var visitsByWebsiteId = Map<String, int>.from(websiteIds.asMap().map(
        (index, key) =>
            MapEntry(key, int.tryParse(websiteVisits[index] ?? 0))));
    websites.forEach((website) {
      website.numberOfVisits = visitsByWebsiteId[website.id] ?? 0;
    });
  }

  /// Increments the number of visits of [website], both in-memory and on the local storage.
  ///
  /// Because [PrefService] doesn't support storing maps, the
  /// data is stored in 2 lists: the list of website IDs ([websiteIds]) and the list
  /// with the number of visits ([websiteVisits]), where `websiteVisits[i]` is the
  /// number of times the user accessed website with ID `websiteIds[i]`.
  void incrementNumberOfVisits(Website website) async {
    website.numberOfVisits++;
    List<String> websiteIds =
        PrefService.sharedPreferences.getStringList('websiteIds') ?? [];
    List<String> websiteVisits =
        PrefService.sharedPreferences.getStringList('websiteVisits') ?? [];

    if (websiteIds.contains(website.id)) {
      int index = websiteIds.indexOf(website.id);
      websiteVisits.insert(index, website.numberOfVisits.toString());
    } else {
      websiteIds.add(website.id);
      websiteVisits.add(website.numberOfVisits.toString());
      PrefService.sharedPreferences.setStringList('websiteIds', websiteIds);
    }
    PrefService.sharedPreferences.setStringList('websiteVisits', websiteVisits);
    notifyListeners();
  }

  Future<List<Website>> fetchWebsites(Filter filter,
      {bool userOnly = false, String uid}) async {
    try {
      List<Website> websites = [];

      if (!userOnly) {
        List<DocumentSnapshot> documents = [];

        if (filter == null) {
          QuerySnapshot qSnapshot =
              await _db.collection('websites').getDocuments();
          documents.addAll(qSnapshot.documents);
        } else {
          // Documents without a 'relevance' field are relevant for everyone
          Query query =
              _db.collection('websites').where('relevance', isNull: true);
          QuerySnapshot qSnapshot = await query.getDocuments();
          documents.addAll(qSnapshot.documents);

          for (String string in filter.relevantNodes) {
            // selected nodes
            Query query = _db
                .collection('websites')
                .where('degree', isEqualTo: filter.baseNode)
                .where('relevance', arrayContains: string);
            QuerySnapshot qSnapshot = await query.getDocuments();
            documents.addAll(qSnapshot.documents);
          }
        }

        // Remove duplicates
        // (a document may result out of more than one query)
        final seenDocumentIds = Set<String>();

        documents = documents
            .where((doc) => seenDocumentIds.add(doc.documentID))
            .toList();

        websites.addAll(documents.map((doc) => WebsiteExtension.fromSnap(doc)));
      }

      // Get user-added websites
      if (uid != null) {
        DocumentReference ref =
            Firestore.instance.collection('users').document(uid);
        QuerySnapshot qSnapshot =
            await ref.collection('websites').getDocuments();

        websites.addAll(qSnapshot.documents
            .map((doc) => WebsiteExtension.fromSnap(doc, ownerUid: uid)));
      }

      initializeNumberOfVisits(websites);
      websites.sort((website1, website2) =>
          website2.numberOfVisits.compareTo(website1.numberOfVisits));

      return websites;
    } catch (e) {
      _errorHandler(e, null);
      return null;
    }
  }

  Future<bool> addWebsite(Website website, {BuildContext context}) async {
    assert(website.label != null);

    try {
      DocumentReference ref;
      if (!website.isPrivate) {
        ref = _db.collection('websites').document(website.id);
      } else {
        ref = _db
            .collection('users')
            .document(website.ownerUid)
            .collection('websites')
            .document(website.id);
      }

      if ((await ref.get()).data != null) {
        // TODO: Properly check if a website with a similar name/link already exists
        print('A website with id ${website.id} already exists');
        if (context != null) {
          AppToast.show(S.of(context).warningWebsiteNameExists);
        }
        return false;
      }

      var data = website.toData();
      await ref.setData(data);

      notifyListeners();
      return true;
    } catch (e) {
      _errorHandler(e, context);
      return false;
    }
  }

  Future<bool> updateWebsite(Website website, {BuildContext context}) async {
    assert(website.label != null);

    try {
      DocumentReference publicRef =
          _db.collection('websites').document(website.id);
      DocumentReference privateRef = _db
          .collection('users')
          .document(website.ownerUid)
          .collection('websites')
          .document(website.id);

      DocumentReference previousRef;
      bool wasPrivate;
      if ((await publicRef.get()).data != null) {
        wasPrivate = false;
        previousRef = publicRef;
      } else if ((await privateRef.get()).data != null) {
        wasPrivate = true;
        previousRef = privateRef;
      } else {
        print('Website not found.');
        return false;
      }

      if (wasPrivate == website.isPrivate) {
        // No privacy change
        await previousRef.updateData(website.toData());
      } else {
        // Privacy changed
        await previousRef.delete();
        await (wasPrivate ? publicRef : privateRef).setData(website.toData());
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorHandler(e, context);
      return false;
    }
  }

  Future<bool> deleteWebsite(Website website, {BuildContext context}) async {
    try {
      DocumentReference ref;
      if (!website.isPrivate) {
        ref = _db.collection('websites').document(website.id);
      } else {
        ref = _db
            .collection('users')
            .document(website.ownerUid)
            .collection('websites')
            .document(website.id);
      }

      await ref.delete();

      notifyListeners();
      return true;
    } catch (e) {
      _errorHandler(e, context);
      return false;
    }
  }
}
