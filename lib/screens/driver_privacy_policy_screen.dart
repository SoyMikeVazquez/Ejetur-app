import 'package:flutter/material.dart';
import 'splash_router_screen.dart';

class DriverPrivacyPolicyScreen extends StatefulWidget {
  const DriverPrivacyPolicyScreen({super.key});

  @override
  State<DriverPrivacyPolicyScreen> createState() => _DriverPrivacyPolicyScreenState();
}

class _DriverPrivacyPolicyScreenState extends State<DriverPrivacyPolicyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Políticas de Privacidad',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // El usuario no puede saltarse este paso hacia atrás
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Términos y Condiciones de Uso',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Política de Privacidad para Conductores – Taxiseguro\n'
                      'Última actualización: Agosto 2026\n\n'
                      'En Taxiseguro, valoramos tu confianza y estamos comprometidos con la protección de tu información personal. Esta Política de Privacidad explica cómo recopilamos, utilizamos, compartimos y protegemos los datos de los conductores ("tú", "el conductor") que utilizan nuestra aplicación móvil y servicios asociados.\n\n'
                      '1. Información que recopilamos\n'
                      'Para que puedas operar en la plataforma y brindarte soporte, necesitamos recopilar ciertos datos:\n'
                      '• Datos de registro y perfil: Nombre completo, dirección, correo electrónico, número de teléfono, fecha de nacimiento y una fotografía de perfil.\n'
                      '• Información y documentos profesionales: Licencia de conducir vigente, tarjeta de circulación, comprobante de seguro del vehículo, comprobante de domicilio y, donde la ley lo permita, antecedentes no penales o historial de conducción.\n'
                      '• Datos financieros: Información de tu cuenta bancaria y datos fiscales (como RFC) para procesar tus ganancias y emitir facturas.\n'
                      '• Datos de ubicación (GPS): Recopilamos datos de ubicación precisa o aproximada de tu dispositivo móvil cuando la app de taxiseguro está ejecutándose en primer plano (app abierta) o en segundo plano (mientras estás "Conectado" o en un viaje). Esto es esencial para emparejarte con pasajeros y calcular tarifas.\n'
                      '• Datos del dispositivo y uso: Modelo de teléfono, sistema operativo, dirección IP, uso de la red y estadísticas de cómo interactúas con la aplicación.\n'
                      '• Comunicaciones: Grabaciones o registros de llamadas y mensajes intercambiados con nuestro equipo de soporte, así como mensajes dentro de la app con los pasajeros.\n'
                      '• Grabaciones de audio y video (Dashcams): Si optas por registrar o utilizar una cámara de seguridad interna (dashcam) en tu vehículo, podremos procesar grabaciones para fines de seguridad y resolución de conflictos.\n\n'
                      '2. Cómo utilizamos tu información\n'
                      'Utilizamos los datos recopilados para los siguientes propósitos:\n'
                      '• Provisión del servicio: Crear tu cuenta, verificar tu identidad y requisitos legales, conectarte con pasajeros cercanos y trazar las rutas de los viajes.\n'
                      '• Pagos: Calcular tus ganancias, procesar transferencias a tu cuenta bancaria y gestionar temas fiscales.\n'
                      '• Programas de Lealtad y Recompensas: Evaluar tu desempeño para ofrecerte bonos y beneficios exclusivos como conductor.\n'
                      '• Seguridad y protección: Monitorear viajes en tiempo real, investigar accidentes o quejas, prevenir fraudes y asegurar que los conductores mantengan los estándares de la plataforma.\n'
                      '• Soporte técnico: Resolver problemas con la app, atender tus consultas y gestionar reclamaciones.\n'
                      '• Mejora de la app: Analizar tendencias de uso para mejorar nuestros algoritmos de asignación, mapas y rendimiento de la aplicación.\n\n'
                      '3. Con quién compartimos tu información\n'
                      'Para que taxiseguro funcione correctamente, es necesario compartir ciertos datos con terceros:\n'
                      '• Con los pasajeros: Una vez que aceptas un viaje, el pasajero verá tu nombre, foto de perfil, calificación promedio, marca, modelo y placas del vehículo, así como tu ubicación en tiempo real.\n'
                      '• Proveedores de servicios: Compartimos datos con empresas que nos ayudan a operar, como procesadores de pago, servicios de verificación de antecedentes, proveedores de almacenamiento en la nube y servicios de mapas (por ejemplo, Google Maps).\n'
                      '• Autoridades gubernamentales o policiales: Podemos compartir tu información si es requerido por ley, orden judicial, o para proteger los derechos, la propiedad y la seguridad de taxiseguro, nuestros usuarios o el público en general.\n\n'
                      '4. Retención de datos\n'
                      'Conservaremos tu información personal mientras tu cuenta de conductor de taxiseguro esté activa. Si decides eliminar tu cuenta, retendremos ciertos datos por el tiempo que exijan las leyes fiscales y de transporte aplicables.\n\n'
                      '5. Tus derechos (Derechos ARCO)\n'
                      'Como titular de tus datos, tienes derecho a:\n'
                      '• Acceder a la información personal que tenemos sobre ti.\n'
                      '• Rectificar cualquier dato que sea inexacto, incompleto o desactualizado.\n'
                      '• Cancelar (eliminar) tu cuenta y tus datos cuando ya no sean necesarios para los fines descritos.\n'
                      '• Oponerte al uso de tus datos para fines específicos.\n'
                      'Para ejercer estos derechos, puedes contactarnos a través de la sección de soporte de la app.\n\n'
                      '6. Seguridad de la información\n'
                      'Implementamos medidas técnicas, administrativas y físicas de seguridad diseñadas para proteger tus datos contra acceso no autorizado, pérdida, alteración o destrucción.\n\n'
                      '7. Cambios a esta Política de Privacidad\n'
                      'Es posible que actualicemos esta política periódicamente. Si realizamos cambios significativos, te notificaremos a través de la aplicación de taxiseguro o por correo electrónico.\n\n'
                      '8. Contacto\n'
                      'Si tienes preguntas, inquietudes o quejas sobre esta Política de Privacidad, por favor contáctanos en:\n'
                      '• Correo electrónico: privacidad@taxiseguro.com\n'
                      '• Teléfono de soporte: (81) 1234-5678\n',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SplashRouterScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF050505), // Modern Black
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Aceptar Políticas',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
