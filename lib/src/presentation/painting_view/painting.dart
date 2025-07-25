// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:provider/provider.dart';
import 'package:vs_story_designer/src/domain/models/painting_model.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/control_provider.dart';
import 'package:vs_story_designer/src/domain/providers/notifiers/painting_notifier.dart';
import 'package:vs_story_designer/src/presentation/painting_view/widgets/sketcher.dart';
import 'package:vs_story_designer/src/presentation/painting_view/widgets/top_painting_tools.dart';
import 'package:vs_story_designer/src/presentation/widgets/color_selector.dart';
import 'package:vs_story_designer/src/presentation/widgets/size_slider_selector.dart';

class Painting extends StatefulWidget {
  const Painting({super.key, required this.doneText});

  final String doneText;

  @override
  State<Painting> createState() => _PaintingState();
}

class _PaintingState extends State<Painting> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Provider.of<PaintingNotifier>(context, listen: false)
        ..linesStreamController =
            StreamController<List<PaintingModel>>.broadcast()
        ..currentLineStreamController =
            StreamController<PaintingModel>.broadcast();
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// instance of painting model
    PaintingModel? line;

    /// screen size
    var screenSize = MediaQueryData.fromView(View.of(context));

    /// on gestures start
    void _onPanStart(DragStartDetails details,
        PaintingNotifier paintingNotifier, ControlNotifier controlProvider) {
      final box = context.findRenderObject() as RenderBox;
      final offset = box.globalToLocal(details.globalPosition);
      final point = PointVector(offset.dx, offset.dy);
      final points = [point];

      /// validate allow pan area
      if (point.y >= 4 &&
          point.y <=
              (Platform.isIOS
                  ? (screenSize.size.height - 132) - screenSize.viewPadding.top
                  : screenSize.size.height - 132)) {
        line = PaintingModel(
            points,
            paintingNotifier.lineWidth,
            1,
            1,
            false,
            controlProvider.colorList![paintingNotifier.lineColor],
            1,
            true,
            paintingNotifier.paintingType);
      }
    }

    /// on gestures update
    void _onPanUpdate(DragUpdateDetails details,
        PaintingNotifier paintingNotifier, ControlNotifier controlNotifier) {
      final box = context.findRenderObject() as RenderBox;
      final offset = box.globalToLocal(details.globalPosition);
      final point = PointVector(offset.dx, offset.dy);
      final points = [...line!.points, point];

      /// validate allow pan area
      if (point.y >= 6 &&
          point.y <=
              (Platform.isIOS
                  ? (screenSize.size.height - 132) - screenSize.viewPadding.top
                  : screenSize.size.height - 132)) {
        line = PaintingModel(
            points,
            paintingNotifier.lineWidth,
            1,
            1,
            false,
            controlNotifier.colorList![paintingNotifier.lineColor],
            1,
            true,
            paintingNotifier.paintingType);
        paintingNotifier.currentLineStreamController.add(line!);
      }
    }

    /// on gestures end
    void _onPanEnd(DragEndDetails details, PaintingNotifier paintingNotifier) {
      paintingNotifier.lines = List.from(paintingNotifier.lines)..add(line!);
      line = null;
      paintingNotifier.linesStreamController.add(paintingNotifier.lines);
    }

    /// paint current line
    Widget _renderCurrentLine(BuildContext context,
        PaintingNotifier paintingNotifier, ControlNotifier controlNotifier) {
      return GestureDetector(
        onPanStart: (details) {
          _onPanStart(details, paintingNotifier, controlNotifier);
        },
        onPanUpdate: (details) {
          _onPanUpdate(details, paintingNotifier, controlNotifier);
        },
        onPanEnd: (details) {
          _onPanEnd(details, paintingNotifier);
        },
        child: RepaintBoundary(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  width: MediaQuery.of(context).size.width,
                  height: Platform.isIOS
                      ? (screenSize.size.height - 132) -
                          screenSize.viewPadding.top
                      : MediaQuery.of(context).size.height - 132,
                  child: StreamBuilder<PaintingModel>(
                      stream:
                          paintingNotifier.currentLineStreamController.stream,
                      builder: (context, snapshot) {
                        return CustomPaint(
                          painter: Sketcher(
                            lines: line == null ? [] : [line!],
                          ),
                        );
                      })),
            ),
          ),
        ),
      );
    }

    /// return Painting board
    return Consumer2<ControlNotifier, PaintingNotifier>(
      builder: (context, controlNotifier, paintingNotifier, child) {
        return PopScope(
          onPopInvokedWithResult: (bool didPop, result) {
            controlNotifier.isPainting = false;
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              paintingNotifier.closeConnection();
            });
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                /// render current line
                _renderCurrentLine(context, paintingNotifier, controlNotifier),

                /// select line width
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 140),
                    child: SizeSliderWidget(),
                  ),
                ),

                /// top painting tools
                SafeArea(child: TopPaintingTools(doneText: widget.doneText)),

                /// color picker
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 110),
                    child: ColorSelector(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
