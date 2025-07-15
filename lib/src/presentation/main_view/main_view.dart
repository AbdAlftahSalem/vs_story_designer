// ignore_for_file: must_be_immutable, library_private_types_in_public_api, no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:vs_media_picker/vs_media_picker.dart';
import 'package:vs_story_designer/src/domain/models/editable_items.dart';
import 'package:vs_story_designer/src/domain/models/painting_model.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/control_provider.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/draggable_widget_notifier.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/gradient_notifier.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/painting_notifier.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/scroll_notifier.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/text_editing_notifier.dart';
import 'package:vs_story_designer/src/presentation/bar_tools/top_tools.dart';
import 'package:vs_story_designer/src/presentation/draggable_items/delete_item.dart';
import 'package:vs_story_designer/src/presentation/draggable_items/draggable_widget.dart';
import 'package:vs_story_designer/src/presentation/painting_view/painting.dart';
import 'package:vs_story_designer/src/presentation/painting_view/widgets/sketcher.dart';
import 'package:vs_story_designer/src/presentation/text_editor_view/TextEditor.dart';
import 'package:vs_story_designer/src/presentation/utils/constants/font_family.dart';
import 'package:vs_story_designer/src/presentation/utils/constants/item_type.dart';
import 'package:vs_story_designer/src/presentation/utils/modal_sheets.dart';
import 'package:vs_story_designer/src/presentation/widgets/animated_onTap_button.dart';
import 'package:vs_story_designer/src/presentation/widgets/scrollable_pageView.dart';
import 'package:vs_story_designer/vs_story_designer.dart';

class MainView extends StatefulWidget {
  final List<FontType>? fontFamilyList;
  final bool? isCustomFontList;
  final String? fileName;
  final String giphyKey;
  final List<List<Color>>? gradientColors;
  final Widget? middleBottomWidget;
  final Function(String) onDone;
  final Widget? onDoneButtonStyle;
  final Future<bool>? onBackPress;
  Color? editorBackgroundColor;
  final int? galleryThumbnailQuality;
  List<Color>? colorList;
  final String? centerText;
  final ThemeType? themeType;
  final String? mediaPath;
  final Widget? backWidget;
  final Widget? textWidget;
  final Widget? drawWidget;
  final Widget? saveWidget;
  final String? cancelText;
  final String? doneText;
  final String closeAlertTitle;
  final String closeAlertDescription;
  final String closeAlertDiscardText;
  final String closeAlertCancelText;
  final BorderRadiusGeometry? borderRadius;
  final List<Widget> bottomWidget;
  final double? highTextEditor;
  final Color? saveCardColor;

  MainView({
    super.key,
    this.themeType,
    required this.giphyKey,
    required this.onDone,
    this.middleBottomWidget,
    this.colorList,
    this.fileName,
    this.isCustomFontList,
    this.fontFamilyList,
    this.gradientColors,
    this.onBackPress,
    this.onDoneButtonStyle,
    this.editorBackgroundColor,
    this.galleryThumbnailQuality,
    this.centerText,
    this.mediaPath,
    this.backWidget,
    this.textWidget,
    this.drawWidget,
    this.saveWidget,
    this.cancelText,
    this.doneText,
    required this.closeAlertTitle,
    required this.closeAlertDescription,
    required this.closeAlertDiscardText,
    required this.closeAlertCancelText,
    this.saveCardColor,
    this.borderRadius,
    required this.bottomWidget,
    this.highTextEditor,
  });

  @override
  _MainViewState createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final GlobalKey contentKey = GlobalKey();
  final GlobalKey _captureKey =
      GlobalKey(); // New key for capturing content without bottom widget

  EditableItem? _activeItem;
  Offset _initPos = const Offset(0, 0);
  Offset _currentPos = const Offset(0, 0);
  double _currentScale = 1;
  double _currentRotation = 0;
  bool _isDeletePosition = false;
  bool _inAction = false;
  final _screenSize = MediaQueryData.fromView(WidgetsBinding.instance.window);

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      var _control = Provider.of<ControlNotifier>(context, listen: false);
      var _tempItemProvider =
          Provider.of<DraggableWidgetNotifier>(context, listen: false);

      _control.giphyKey = widget.giphyKey;
      _control.folderName = widget.fileName ?? "VS_Story_Designer";
      _control.middleBottomWidget = widget.middleBottomWidget;
      _control.isCustomFontList = widget.isCustomFontList ?? false;
      _control.themeType = widget.themeType ?? ThemeType.dark;
      if (widget.mediaPath != null) {
        _control.mediaPath = widget.mediaPath!;
        _tempItemProvider.draggableWidget.insert(
            0,
            EditableItem()
              ..type = ItemType.image
              ..position = const Offset(0.0, 0));
      }
      if (widget.gradientColors != null) {
        _control.gradientColors = widget.gradientColors;
      }
      if (widget.fontFamilyList != null) {
        _control.fontList = widget.fontFamilyList;
      }
      if (widget.colorList != null) {
        _control.colorList = widget.colorList;
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String?> _takePictureWithoutBottomWidget({
    required bool saveToGallery,
    required String fileName,
  }) async {
    try {
      RenderRepaintBoundary boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final String dir = (await getApplicationDocumentsDirectory()).path;
      String imagePath =
          '$dir/${fileName}_${DateTime.now().millisecondsSinceEpoch}.png';
      File capturedFile = File(imagePath);
      await capturedFile.writeAsBytes(pngBytes);

      if (saveToGallery) {
        final result = await ImageGallerySaverPlus.saveImage(
          pngBytes,
          quality: 100,
          name: "${fileName}_${DateTime.now().millisecondsSinceEpoch}.png",
        );
        if (result == null || !result['isSuccess']) {
          debugPrint('Failed to save image to gallery');
        }
      }

      return imagePath;
    } catch (e) {
      debugPrint('exception => $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, result) {
        if (didPop) return;
        _popScope();
      },
      child: Material(
        color: widget.editorBackgroundColor == Colors.transparent
            ? Colors.black
            : widget.editorBackgroundColor ?? Colors.black,
        child: Consumer6<
            ControlNotifier,
            DraggableWidgetNotifier,
            ScrollNotifier,
            GradientNotifier,
            PaintingNotifier,
            TextEditingNotifier>(
          builder: (context, controlNotifier, itemProvider, scrollProvider,
              colorProvider, paintingProvider, editingProvider, child) {
            return SafeArea(
              child: Stack(
                children: [
                  ScrollablePageView(
                    scrollPhysics: controlNotifier.mediaPath.isEmpty &&
                        itemProvider.draggableWidget.isEmpty &&
                        !controlNotifier.isPainting &&
                        !controlNotifier.isTextEditing,
                    pageController: scrollProvider.pageController,
                    gridController: scrollProvider.gridController,
                    mainView: Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          onTap: () {
                            controlNotifier.isTextEditing =
                                !controlNotifier.isTextEditing;
                          },
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ClipRRect(
                              borderRadius: widget.borderRadius ??
                                  BorderRadius.circular(8),
                              child: SizedBox(
                                width: _screenSize.size.width,
                                height: widget.highTextEditor ??
                                    (Platform.isIOS
                                        ? (_screenSize.size.height - 135) -
                                            _screenSize.viewPadding.top
                                        : (_screenSize.size.height - 132)),
                                child: RepaintBoundary(
                                  key: _captureKey, // Using the new capture key
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                        gradient:
                                            controlNotifier.mediaPath.isEmpty
                                                ? LinearGradient(
                                                    colors: controlNotifier
                                                            .gradientColors![
                                                        controlNotifier
                                                            .gradientIndex],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : LinearGradient(
                                                    colors: [
                                                      colorProvider.color1,
                                                      colorProvider.color2
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  )),
                                    child: GestureDetector(
                                      onScaleStart: _onScaleStart,
                                      onScaleUpdate: _onScaleUpdate,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          PhotoView.customChild(
                                            backgroundDecoration:
                                                const BoxDecoration(
                                                    color: Colors.transparent),
                                            child: Container(),
                                          ),
                                          ...itemProvider.draggableWidget.map(
                                              (editableItem) => DraggableWidget(
                                                    context: context,
                                                    draggableWidget:
                                                        editableItem,
                                                    onPointerDown: (details) {
                                                      _updateItemPosition(
                                                        editableItem,
                                                        details,
                                                      );
                                                    },
                                                    onPointerUp: (details) {
                                                      _deleteItemOnCoordinates(
                                                        editableItem,
                                                        details,
                                                      );
                                                    },
                                                    onPointerMove: (details) {
                                                      _deletePosition(
                                                        editableItem,
                                                        details,
                                                      );
                                                    },
                                                  )),
                                          IgnorePointer(
                                            ignoring: true,
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                                child: RepaintBoundary(
                                                  child: SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height -
                                                            132,
                                                    child: StreamBuilder<
                                                        List<PaintingModel>>(
                                                      stream: paintingProvider
                                                          .linesStreamController
                                                          .stream,
                                                      builder:
                                                          (context, snapshot) {
                                                        return CustomPaint(
                                                          painter: Sketcher(
                                                            lines:
                                                                paintingProvider
                                                                    .lines,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (itemProvider.draggableWidget.isEmpty &&
                            !controlNotifier.isTextEditing &&
                            paintingProvider.lines.isEmpty)
                          IgnorePointer(
                            ignoring: true,
                            child: Align(
                              alignment: const Alignment(0, -0.1),
                              child: Text(
                                widget.centerText!,
                                style: AppFonts.getTextThemeENUM(
                                        FontType.garamond)
                                    .bodyLarge!
                                    .merge(
                                      TextStyle(
                                        package: 'vs_story_designer',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 25,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        shadows: !controlNotifier
                                                .enableTextShadow
                                            ? []
                                            : <Shadow>[
                                                Shadow(
                                                    offset:
                                                        const Offset(1.0, 1.0),
                                                    blurRadius: 3.0,
                                                    color: Colors.black45
                                                        .withValues(alpha: 0.3))
                                              ],
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        Visibility(
                          visible: !controlNotifier.isTextEditing &&
                              !controlNotifier.isPainting,
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: TopTools(
                                contentKey: contentKey,
                                context: context,
                                backWidget: widget.backWidget,
                                drawWidget: widget.drawWidget,
                                saveWidget: widget.saveWidget,
                                textWidget: widget.textWidget,
                                closeAlertDescription:
                                    widget.closeAlertDescription,
                                closeAlertCancelText:
                                    widget.closeAlertCancelText,
                                closeAlertDiscardText:
                                    widget.closeAlertDiscardText,
                                closeAlertTitle: widget.closeAlertTitle,
                                saveCardColor:
                                    widget.saveCardColor ?? Colors.white,
                              )),
                        ),
                        DeleteItem(
                          activeItem: _activeItem,
                          animationsDuration: const Duration(milliseconds: 300),
                          isDeletePosition: _isDeletePosition,
                        ),
                        if (!kIsWeb)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Wrap(
                              children: List.generate(
                                  widget.bottomWidget.length,
                                  (index) => GestureDetector(
                                        onTap: () async {
                                          var response =
                                              await _takePictureWithoutBottomWidget(
                                            saveToGallery: true,
                                            fileName:
                                                controlNotifier.folderName,
                                          );
                                          widget.onDone(response ?? "");
                                        },
                                        child: widget.bottomWidget[index],
                                      )),
                            ),
                          ),
                        Visibility(
                          visible: controlNotifier.isTextEditing,
                          child: TextEditor(
                            context: context,
                            doneText: widget.doneText ?? 'Done',
                          ),
                        ),
                        Visibility(
                          visible: controlNotifier.isPainting,
                          child: Painting(
                            doneText: widget.doneText ?? 'Done',
                          ),
                        )
                      ],
                    ),
                    gallery: VSMediaPicker(
                      gridViewController: scrollProvider.gridController,
                      thumbnailQuality: widget.galleryThumbnailQuality,
                      singlePick: true,
                      onlyImages: true,
                      appBarColor: widget.editorBackgroundColor ?? Colors.black,
                      gridViewPhysics: itemProvider.draggableWidget.isEmpty
                          ? const NeverScrollableScrollPhysics()
                          : const ScrollPhysics(),
                      pathList: (path) {
                        controlNotifier.mediaPath = path[0].path!;
                        if (controlNotifier.mediaPath.isNotEmpty) {
                          itemProvider.draggableWidget.insert(
                              0,
                              EditableItem()
                                ..type = ItemType.image
                                ..position = const Offset(0.0, 0));
                        }
                        scrollProvider.pageController.animateToPage(0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn);
                      },
                      appBarLeadingWidget: Padding(
                        padding: const EdgeInsets.only(bottom: 15, right: 15),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: AnimatedOnTapButton(
                            onTap: () {
                              scrollProvider.pageController.animateToPage(0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeIn);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  )),
                              child: Text(
                                widget.cancelText ?? 'Cancel',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<bool> _popScope() async {
    final controlNotifier =
        Provider.of<ControlNotifier>(context, listen: false);

    if (controlNotifier.isTextEditing) {
      controlNotifier.isTextEditing = !controlNotifier.isTextEditing;
      return false;
    } else if (controlNotifier.isPainting) {
      controlNotifier.isPainting = !controlNotifier.isPainting;
      return false;
    } else if (!controlNotifier.isTextEditing && !controlNotifier.isPainting) {
      return widget.onBackPress ??
          exitDialog(
            context: context,
            contentKey: contentKey,
            themeType: widget.themeType!,
            cancelText: widget.closeAlertCancelText,
            description: widget.closeAlertDescription,
            title: widget.closeAlertTitle,
            discardText: widget.closeAlertDiscardText,
          );
    }
    return false;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_activeItem == null) {
      return;
    }
    _initPos = details.focalPoint;
    _currentPos = _activeItem!.position;
    _currentScale = _activeItem!.scale;
    _currentRotation = _activeItem!.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_activeItem == null) {
      return;
    }
    final delta = details.focalPoint - _initPos;

    final left = (delta.dx / _screenSize.size.width) + _currentPos.dx;
    final top = (delta.dy / _screenSize.size.height) + _currentPos.dy;

    setState(() {
      _activeItem!.position = Offset(left, top);
      _activeItem!.rotation = details.rotation + _currentRotation;
      _activeItem!.scale = details.scale * _currentScale;
    });
  }

  void _deletePosition(EditableItem item, PointerMoveEvent details) {
    final widgetHeight = widget.highTextEditor ??
        (Platform.isIOS
            ? (_screenSize.size.height - 135) - _screenSize.viewPadding.top
            : (_screenSize.size.height - 132));

    const deleteZoneBottomOffset = 130.0;
    final deleteZoneDy = 0.5 - (deleteZoneBottomOffset / widgetHeight);

    const deleteZoneDxMin = -0.15;
    const deleteZoneDxMax = 0.15;

    debugPrint('Item position: (${item.position.dx}, ${item.position.dy})');
    debugPrint(
        'Delete zone: dy >= $deleteZoneDy, dx: [$deleteZoneDxMin, $deleteZoneDxMax]');

    if ((item.type == ItemType.text || item.type == ItemType.gif) &&
        item.position.dy >= deleteZoneDy &&
        item.position.dx >= deleteZoneDxMin &&
        item.position.dx <= deleteZoneDxMax) {
      setState(() {
        _isDeletePosition = true;
        item.deletePosition = true;
      });
    } else {
      setState(() {
        _isDeletePosition = false;
        item.deletePosition = false;
      });
    }
  }

  void _deleteItemOnCoordinates(EditableItem item, PointerUpEvent details) {
    var _itemProvider =
        Provider.of<DraggableWidgetNotifier>(context, listen: false)
            .draggableWidget;
    _inAction = false;

    final widgetHeight = widget.highTextEditor ??
        (Platform.isIOS
            ? (_screenSize.size.height - 135) - _screenSize.viewPadding.top
            : (_screenSize.size.height - 132));

    const deleteZoneBottomOffset = 130.0;
    final deleteZoneDy = 0.5 - (deleteZoneBottomOffset / widgetHeight);

    const deleteZoneDxMin = -0.15;
    const deleteZoneDxMax = 0.15;

    debugPrint('Release position: (${item.position.dx}, ${item.position.dy})');
    debugPrint(
        'Delete zone: dy >= $deleteZoneDy, dx: [$deleteZoneDxMin, $deleteZoneDxMax]');

    if (item.type == ItemType.image) {
      // Image items are not deleted
    } else if ((item.type == ItemType.text || item.type == ItemType.gif) &&
        item.position.dy >= deleteZoneDy &&
        item.position.dx >= deleteZoneDxMin &&
        item.position.dx <= deleteZoneDxMax) {
      setState(() {
        _itemProvider.removeAt(_itemProvider.indexOf(item));
        HapticFeedback.heavyImpact();
        debugPrint('Item deleted: ${item.type}');
      });
    } else {
      setState(() {
        _activeItem = null;
      });
    }
    setState(() {
      _activeItem = null;
    });
  }

  void _updateItemPosition(EditableItem item, PointerDownEvent details) {
    if (_inAction) {
      return;
    }

    _inAction = true;
    _activeItem = item;
    _initPos = details.position;
    _currentPos = item.position;
    _currentScale = item.scale;
    _currentRotation = item.rotation;

    HapticFeedback.lightImpact();
  }
}
