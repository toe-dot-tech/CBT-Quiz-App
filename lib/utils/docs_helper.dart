import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class DocxHelper {
  // Extract text from DOCX file
  static Future<String?> extractTextFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Find the document.xml file in the archive
      final documentFile = archive.findFile('word/document.xml');
      if (documentFile == null) {
        print('Could not find document.xml in the DOCX file');
        return null;
      }
      
      // Extract the XML content
      final xmlContent = utf8.decode(documentFile.content);
      final document = XmlDocument.parse(xmlContent);
      
      // Extract text from all paragraph elements
      final paragraphs = document.findAllElements('w:p');
      final textParts = <String>[];
      
      for (var paragraph in paragraphs) {
        final texts = paragraph.findAllElements('w:t');
        for (var text in texts) {
          final textContent = text.innerText.trim();
          if (textContent.isNotEmpty) {
            textParts.add(textContent);
          }
        }
      }
      
      // Join with newlines to maintain structure
      return textParts.join('\n');
    } catch (e) {
      print('Error extracting DOCX: $e');
      return null;
    }
  }
  
  // Alternative: Extract with basic structure preservation
  static Future<String?> extractWithStructure(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final documentFile = archive.findFile('word/document.xml');
      if (documentFile == null) return null;
      
      final xmlContent = utf8.decode(documentFile.content);
      final document = XmlDocument.parse(xmlContent);
      
      final result = StringBuffer();
      
      // Process paragraphs with their styling
      final paragraphs = document.findAllElements('w:p');
      for (var paragraph in paragraphs) {
        final texts = paragraph.findAllElements('w:t');
        for (var text in texts) {
          result.write(text.innerText.trim());
        }
        
        // Check if it's a heading or has numbering
        final pStyle = paragraph.findElements('w:pStyle').firstOrNull;
        if (pStyle != null) {
          final styleVal = pStyle.getAttribute('w:val');
          if (styleVal != null && styleVal.contains('Heading')) {
            result.write('\n'); // Add extra newline after headings
          }
        }
        
        // Check for numbering (questions)
        final numPr = paragraph.findElements('w:numPr').firstOrNull;
        if (numPr != null) {
          // This is likely a numbered item (question)
          result.write('\n');
        } else {
          result.write(' ');
        }
      }
      
      return result.toString();
    } catch (e) {
      print('Error extracting structured DOCX: $e');
      return null;
    }
  }
}