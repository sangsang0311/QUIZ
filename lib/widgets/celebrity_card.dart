import 'dart:io';
import 'package:flutter/material.dart';
import '../models/celebrity.dart';

class CelebrityCard extends StatelessWidget {
  final Celebrity celebrity;
  final bool showName;

  const CelebrityCard({
    super.key,
    required this.celebrity,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // 이미지
          AspectRatio(
            aspectRatio: 3 / 4,
            child: _buildImage(context),
          ),
          
          // 이름 (showName이 true일 때만 표시)
          if (showName)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(
                  celebrity.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 3.0,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    try {
      // 파일 경로가 /로 시작하거나, 드라이브 경로(C:\ 등)면 파일로 처리
      if (celebrity.imagePath.startsWith('/') ||
          celebrity.imagePath.contains(':\\')) {
        return Image.file(
          File(celebrity.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else {
        // 그렇지 않으면 에셋으로 처리
        return Image.asset(
          celebrity.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              celebrity.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
} 