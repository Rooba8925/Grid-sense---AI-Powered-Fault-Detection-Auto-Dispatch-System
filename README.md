⚡ GridSense: AI-Powered Fault Detection & Auto-Dispatch System

📌 Overview

GridSense is an IoT-based smart monitoring system designed to improve fault detection and response in power distribution networks. It uses an ESP32 microcontroller to simulate electrical parameters like voltage and current, detect faults, and notify users through a cloud-based system.
The project demonstrates a complete workflow from data simulation → fault detection → cloud update → alert notification, making it a scalable solution for smart grid applications.


🚀 Features

🔍 Real-time monitoring of voltage and current (simulated)
⚠️ Instant fault detection using threshold-based logic
📟 LCD display for live system status
🔘 Push button for manual fault simulation
☁️ Cloud integration using Supabase
📱 Mobile app notifications for linemen
🔄 Continuous monitoring loop
💰 Low-cost and scalable design

🛠️ Tech Stack


Hardware
ESP32 Microcontroller
16x2 LCD Display
Push Button
Breadboard & Jumper Wires
Software
Arduino IDE
Embedded C / Arduino C
Supabase (Backend)
Wi-Fi (ESP32 connectivity)

🧠 System Architecture


The system works in the following flow:

Simulated voltage & current values are generated
ESP32 processes the data
Fault is detected using predefined logic
Data is sent to the cloud (Supabase)
Alerts are triggered and sent to users
LCD displays real-time status


📊 Modules

Power Distribution Simulation
ESP32 Controller Unit
Data Generation Module
Fault Detection Module
Display Module (LCD)
Input Control Module


⚙️ How It Works

Under normal conditions, the system displays stable voltage and current values.
When the push button is pressed:
Fault condition is triggered
Values change abnormally
System detects fault instantly
Alert is generated and displayed


🧪 Testing
The system was tested using:

Unit Testing (individual components)
Integration Testing (full workflow)
Performance Testing (response time)
Reliability Testing (hardware stability)
Usability Testing (ease of use)


📈 Results

Successfully detects faults in real-time
Provides instant visual feedback via LCD
Ensures quick response through notifications
Operates reliably with low-cost hardware


🎯 Objectives
Develop a real-time monitoring system
Detect faults efficiently
Reduce manual monitoring
Provide a safe simulation environment
Enable future smart grid integration


🔮 Future Enhancements
Integration of real sensors (voltage/current)
AI/ML-based fault prediction
Advanced mobile application
SMS/Notification alert system
Data logging & analytics
GPS-based fault location tracking


🌍 SDG Goals
⚡ Affordable & Clean Energy (SDG 7)
🏙️ Sustainable Cities (SDG 11)
🏗️ Industry Innovation (SDG 9)


👩‍💻 Authors
Praneeta R
Rooba B
Sadhana G


🏫 Institution

M. Kumarasamy College of Engineering, Karur
B.Tech – Artificial Intelligence and Data Science (2025–2026)

📄 License

This project is developed for academic purposes. You can modify and extend it for learning and research.
