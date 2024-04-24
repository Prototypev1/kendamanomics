import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kendamanomics_mobile/mixins/logger_mixin.dart';
import 'package:kendamanomics_mobile/models/bottom_navigation_data.dart';
import 'package:kendamanomics_mobile/pages/leaderboards.dart';
import 'package:kendamanomics_mobile/pages/profile_page.dart';
import 'package:kendamanomics_mobile/pages/tamas_page.dart';
import 'package:kendamanomics_mobile/services/appearance_service.dart';
import 'package:kendamanomics_mobile/services/auth_service.dart';
import 'package:kendamanomics_mobile/services/user_service.dart';
import 'package:kiwi/kiwi.dart';

class MainPageContainerProvider extends ChangeNotifier with LoggerMixin {
  final _authService = KiwiContainer().resolve<AuthService>();
  final _userService = KiwiContainer().resolve<UserService>();
  final _appearanceService = KiwiContainer().resolve<AppearanceService>();

  final _contentGlobalKey = GlobalKey();
  final Color defaultBackgroundColor;
  List<BottomNavigationData> _bottomNav = <BottomNavigationData>[];
  String _previousImagePath = '';
  int _pageIndex = 1;
  double _contentHeight = 0.0;
  ColorTween? _backgroundTween;

  List<BottomNavigationData> get bottomNav => _bottomNav;
  GlobalKey get contentGlobalKey => _contentGlobalKey;
  int get pageIndex => _pageIndex;
  double get contentHeight => _contentHeight;
  ColorTween? get backgroundTween => _backgroundTween;

  set pageIndex(int index) {
    _pageIndex = index;
    notifyListeners();
  }

  MainPageContainerProvider({required this.defaultBackgroundColor}) {
    _backgroundTween = ColorTween(begin: defaultBackgroundColor, end: defaultBackgroundColor);
    _initBottomNav();
    _initListeners();
  }

  void _initListeners() {
    _userService.subscribe(_listenToUserService);
    _appearanceService.subscribe(_listenToAppearanceService);
  }

  void _listenToUserService(UserServiceEvents event, dynamic params) async {
    switch (event) {
      case UserServiceEvents.imageUploaded:
        bool shouldRebuild = _initBottomNav();
        if (shouldRebuild) notifyListeners();
        break;
    }
  }

  void _listenToAppearanceService(AppearanceEvent event, dynamic params) {
    switch (event) {
      case AppearanceEvent.themeChanged:
        break;
      case AppearanceEvent.tamaPageSwiped:
        _updateBackgroundTween(newColor: params.first, postFrameRebuild: params[1]);
        break;
    }
  }

  void calculateContentHeight() {
    if (_contentHeight != 0.0) return;
    final renderBox = _contentGlobalKey.currentContext?.findRenderObject() as RenderBox;
    _contentHeight = renderBox.size.height;
  }

  bool _initBottomNav() {
    final profileImagePath = _authService.player!.playerImageUrl;
    if (profileImagePath != null && profileImagePath.startsWith(_previousImagePath) && _previousImagePath.isNotEmpty) {
      return false;
    }
    if (profileImagePath != null) {
      _previousImagePath = profileImagePath.split('?')[0];
    }

    _bottomNav = [];
    _bottomNav.addAll([
      const BottomNavigationData(
        pathOrUrl: 'assets/icon/icon_leaderboard.png',
        isLocal: true,
        pageName: Leaderboards.pageName,
      ),
      const BottomNavigationData(pathOrUrl: 'assets/icon/icon_tama.png', isLocal: true, pageName: TamasPage.pageName),
      BottomNavigationData(
        pathOrUrl: profileImagePath,
        isLocal: false,
        pageName: ProfilePage.pageName,
        extraData: _authService.getCurrentUserId(),
      ),
    ]);

    return true;
  }

  void _updateBackgroundTween({Color? newColor, bool postFrameRebuild = false}) {
    final beginColor = _backgroundTween!.end;
    Color endColor;
    if (newColor == null) {
      endColor = defaultBackgroundColor;
    } else {
      endColor = newColor;
    }

    _backgroundTween = ColorTween(begin: beginColor, end: endColor);
    if (postFrameRebuild) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _disposeListeners() {
    _userService.unsubscribe(_listenToUserService);
    _appearanceService.unsubscribe(_listenToAppearanceService);
  }

  @override
  void dispose() {
    _disposeListeners();
    super.dispose();
  }

  @override
  String get className => 'MainPageContainerProvider';
}
