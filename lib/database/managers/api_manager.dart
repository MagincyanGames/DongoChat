import 'dart:collection';
import 'dart:convert';

import 'package:dongo_chat/database/database_service.dart';
import 'package:dongo_chat/database/managers/cached_data.dart';
import 'package:dongo_chat/models/sizeable.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';

abstract class ApiManager<T extends Sizeable> implements Sizeable {
  final DatabaseService databaseService;
  final _cache = CachedData();
  bool get needAuth; // Default to requiring auth, override as needed

  int _maxRetryAttempts = 3;
  Duration _retryDelay = const Duration(seconds: 1);

  // Configurable base URL
  // static String baseUrl = 'https://dongoserver.onrender.com/api';
  static String baseUrl = 'http://play.onara.top:10000/api';

  // Allow setting a different base URL for testing or production environments
  static void setBaseUrl(String url) {
    baseUrl = url;
  }

  ApiManager(this.databaseService);

  String get auth => databaseService.auth ?? '';

  String get endpoint;

  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T item);

  bool get useCache;

  String get url => '$baseUrl/$endpoint';

  @override
  int get size => _cache.size;

  // Helper method to build headers with authentication when needed
  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};

    if (needAuth && auth.isNotEmpty) {
      headers['Authorization'] = 'Bearer $auth';
    }

    return headers;
  }

  // Build a URL with a custom route
  String buildCustomUrl(String route) {
    if (route.startsWith('/')) {
      route = route.substring(1);
    }
    return '$url/$route';
  }

  // Helper method to determine if we should retry based on error type
  bool _shouldRetry(int statusCode, Exception? error) {
    // Don't retry on client errors (4xx status codes except specific ones)
    if (statusCode >= 400 && statusCode < 500) {
      // We might want to retry on 408 Request Timeout or 429 Too Many Requests
      return statusCode == 408 || statusCode == 429;
    }

    // Retry on server errors (5xx) or network-related exceptions
    return statusCode >= 500 ||
        error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException');
  }

  // GET operation - retrieve an item by ID with improved retry logic
  Future<T?> Get(ObjectId id) async {
    // Check cache first if caching is enabled
    if (useCache && _cache.containsCached(id)) {
      final cachedData = _cache.getCached(id) as T?;
      return cachedData;
    }

    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetryAttempts) {
      try {
        // Construct the full URL with the ID
        final requestUrl = '$url/${id.oid}';

        // Make the HTTP GET request with auth headers if needed
        final response = await http.get(
          Uri.parse(requestUrl),
          headers: _getHeaders(),
        );

        // Check if the request was successful
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          final item = fromMap(responseData);

          // Cache the result if caching is enabled
          if (useCache) {
            _cache.storeCached(id, item);
          }

          return item;
        } else {
          // Only increment attempts if we should retry based on status code
          if (_shouldRetry(response.statusCode, null)) {
            attempts++;
            if (attempts < _maxRetryAttempts) {
              await Future.delayed(_retryDelay * attempts);
              continue;
            }
          }

          // Don't retry for client errors or if we've exhausted retries
          throw Exception(
            'Failed to load data: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception('Unknown error: $e');

        // Only retry for network-related errors
        if (_shouldRetry(0, lastException)) {
          attempts++;
          if (attempts < _maxRetryAttempts) {
            await Future.delayed(_retryDelay * attempts);
            continue;
          }
        } else {
          // Don't retry for other types of errors
          throw lastException;
        }
      }
    }

    // All attempts failed
    throw lastException ??
        Exception('Failed to retrieve data after $_maxRetryAttempts attempts');
  }

  // POST operation - create a new item
  Future<T?> Post(T item) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetryAttempts) {
      try {
        // Serialize the item to JSON
        final itemMap = toMap(item);
        final jsonBody = jsonEncode(itemMap);

        // Make the HTTP POST request with auth headers if needed
        final response = await http.post(
          Uri.parse(url),
          headers: _getHeaders(),
          body: jsonBody,
        );

        // Check if the request was successful
        if (response.statusCode == 201 || response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final createdItem = fromMap(responseData);

          // Cache the result if caching is enabled and an ID was returned
          if (useCache && responseData['_id'] != null) {
            final id = ObjectId.parse(responseData['_id']);
            _cache.storeCached(id, createdItem);
          }
          return createdItem;
        } else {
          // Only increment attempts if we should retry based on status code
          if (_shouldRetry(response.statusCode, null)) {
            attempts++;
            if (attempts < _maxRetryAttempts) {
              await Future.delayed(_retryDelay * attempts);
              continue;
            }
          }

          // Don't retry for client errors or if we've exhausted retries
          throw Exception(
            'Failed to create data: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception('Unknown error: $e');

        // Only retry for network-related errors
        if (_shouldRetry(0, lastException)) {
          attempts++;
          if (attempts < _maxRetryAttempts) {
            await Future.delayed(_retryDelay * attempts);
            continue;
          }
        } else {
          // Don't retry for other types of errors
          throw lastException;
        }
      }
    }

    // All attempts failed
    throw lastException ??
        Exception('Failed to create data after $_maxRetryAttempts attempts');
  }

  // PUT operation - update an existing item
  Future<T?> Put(ObjectId id, T item) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetryAttempts) {
      try {
        // Serialize the item to JSON
        final itemMap = toMap(item);
        final jsonBody = jsonEncode(itemMap);

        // Construct the full URL with the ID
        final requestUrl = '$url/${id.oid}';

        // Make the HTTP PUT request with auth headers if needed
        final response = await http.put(
          Uri.parse(requestUrl),
          headers: _getHeaders(),
          body: jsonBody,
        );

        // Check if the request was successful
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final updatedItem = fromMap(responseData);

          // Update the cache if caching is enabled
          if (useCache) {
            _cache.storeCached(id, updatedItem);
          }

          return updatedItem;
        } else {
          // Only increment attempts if we should retry based on status code
          if (_shouldRetry(response.statusCode, null)) {
            attempts++;
            if (attempts < _maxRetryAttempts) {
              await Future.delayed(_retryDelay * attempts);
              continue;
            }
          }

          // Don't retry for client errors or if we've exhausted retries
          throw Exception(
            'Failed to update data: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception('Unknown error: $e');

        // Only retry for network-related errors
        if (_shouldRetry(0, lastException)) {
          attempts++;
          if (attempts < _maxRetryAttempts) {
            await Future.delayed(_retryDelay * attempts);
            continue;
          }
        } else {
          // Don't retry for other types of errors
          throw lastException;
        }
      }
    }

    // All attempts failed
    throw lastException ??
        Exception('Failed to update data after $_maxRetryAttempts attempts');
  }

  // DELETE operation - remove an item
  Future<bool> Delete(ObjectId id) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetryAttempts) {
      try {
        // Construct the full URL with the ID
        final requestUrl = '$url/${id.oid}';

        // Make the HTTP DELETE request with auth headers if needed
        final response = await http.delete(
          Uri.parse(requestUrl),
          headers: _getHeaders(),
        );

        // Check if the request was successful
        if (response.statusCode == 200 || response.statusCode == 204) {
          // Remove from cache if caching is enabled
          if (useCache) {
            _cache.removeCached(id);
          }

          return true;
        } else {
          // Only increment attempts if we should retry based on status code
          if (_shouldRetry(response.statusCode, null)) {
            attempts++;
            if (attempts < _maxRetryAttempts) {
              await Future.delayed(_retryDelay * attempts);
              continue;
            }
          }

          // Don't retry for client errors or if we've exhausted retries
          throw Exception(
            'Failed to delete data: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception('Unknown error: $e');

        // Only retry for network-related errors
        if (_shouldRetry(0, lastException)) {
          attempts++;
          if (attempts < _maxRetryAttempts) {
            await Future.delayed(_retryDelay * attempts);
            continue;
          }
        } else {
          // Don't retry for other types of errors
          throw lastException;
        }
      }
    }

    // All attempts failed
    throw lastException ??
        Exception('Failed to delete data after $_maxRetryAttempts attempts');
  }
}
