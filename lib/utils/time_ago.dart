class TimeAgo {
  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    // Si han pasado más de 5 minutos, mostrar la hora exacta
    if (difference.inMinutes > 5) {
      // Formato de hora HH:MM
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    }
    
    // Menos de 5 minutos, mostrar tiempo relativo
    if (difference.inSeconds < 60) {
      return "Ahora mismo";
    } else if (difference.inMinutes < 2) {
      return "Hace un minuto";
    } else {
      return "Hace ${difference.inMinutes} minutos";
    }
  }
}