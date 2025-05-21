#include <util/atomic.h> // For the ATOMIC_BLOCK macro
#include <math.h>
#include <PID_v1.h>

#define ENCA 2 // YELLOW
#define ENCB 3 // WHITE
#define PWMA 10 //motor pwm
#define ENA 12 //motor enable / direction
#define BUZZER 4

#define GEARRATIO 19.0
#define ENCODERIPR 16.0

#define TARGET_RPM 450.00 

#define DEBUG_MODE 0 //turning this on will make calculations inaccurate because of the processing requirement of the serial output

double heatUpRpm[] = {230.00, 280.00, 330.00, 380.00, 450.00};
int heatUpPwm[] = {29000, 33000, 38000, 48000, 56000};
int heatUpStepLength = 5;
int heatUpStepMinTime = 10000; //millis
int heatUpStep = 0;
unsigned long heatUpStepMillis = 0;


volatile double revolutions = 0;
double rev0 = 0;
double itc = 0; //interrupt count
int itcSampleRate = 20000; //microseconds
int itcSampleRateMoreMagic = itcSampleRate-8; //don't ask about the -8
unsigned long lastMicros = 0;
unsigned long slowLoopMillis = 0;
unsigned long buzzerMillis = 0;
int buzzerBeepCounter = 0;
int buzzerBeepState = 0;
double currentPwm = 16000;
double currentPwmDelta = 0;
double itcCurrentTarget = 0;
double itcPositionDiff = 0;
double itcPositionTarget = 0; //should remain 0

double Kp=0.1, Ki=0, Kd=6;
PID myPID(&itcPositionDiff, &currentPwmDelta, &itcPositionTarget, Kp, Ki, Kd, DIRECT);

void setup() {
  if(DEBUG_MODE != 0){
    Serial.begin(9600);
  }
  pinMode(ENCA,INPUT);
  pinMode(ENCB,INPUT);
  attachInterrupt(digitalPinToInterrupt(ENCA),readEncoder,RISING);
  
  pinMode(PWMA,OUTPUT);
  pinMode(ENA,OUTPUT);
  digitalWrite(ENA, HIGH);
  pinMode(BUZZER,OUTPUT);
  digitalWrite(BUZZER, LOW);
  delay(200);
  buzzerBeep(1);
  myPID.SetMode(AUTOMATIC);
  myPID.SetOutputLimits(-100.0, 100.0);
  //set the timer 1 PWM to 16 bits
  TCCR1A = (1 << WGM11) | (1 << COM1B1);
  TCCR1B = (1 << WGM13) | (1 << WGM12) | (1 << CS10);
  ICR1 = 65535;
  OCR1B = 0;
}

void loop() {
  //count rpm
  ATOMIC_BLOCK(ATOMIC_RESTORESTATE) {
    rev0 += revolutions;
    revolutions = 0;
  }
  if (micros() - lastMicros >= itcSampleRateMoreMagic || micros() < lastMicros) { 
    lastMicros = micros();
    itc = rev0; 
    rev0 = 0;
    //
    itcPositionDiff += (itc - itcCurrentTarget);
    if(itcPositionDiff < (itcCurrentTarget*-1)){
      itcPositionDiff = itcCurrentTarget *-1;
    }
    if(itcPositionDiff > itcCurrentTarget){
      itcPositionDiff = itcCurrentTarget;
    }
    myPID.Compute();
    currentPwm += currentPwmDelta;
    if (currentPwm<0.0) currentPwm =0.0;
    if (currentPwm>65535.0) currentPwm = 65535.0;
    unsigned int tpwm = (unsigned int) currentPwm;
    OCR1B = tpwm;

    if (millis() - slowLoopMillis >= 1000) {
      //slow loop
      if(heatUpStep < heatUpStepLength) {
        if(heatUpStepMillis < millis()){
          if(itcCurrentTarget == 0){
            //no ipm target set, start heat up sequence
            itcCurrentTarget = rpmToItc(heatUpRpm[heatUpStep]);
            heatUpStepMillis = millis() + heatUpStepMinTime;
          }
          //heatup mode
          if(itc >= itcCurrentTarget && tpwm < heatUpPwm[heatUpStep]){
            //heat up pwm reached, increase heatupstep
            heatUpStep += 1;
            if(heatUpStep < heatUpStepLength){
              itcCurrentTarget = rpmToItc(heatUpRpm[heatUpStep]);
              heatUpStepMillis = millis() + heatUpStepMinTime;
              buzzerBeep(1);
            }else{
              //heat up complete
              itcCurrentTarget = rpmToItc(TARGET_RPM);
              buzzerBeep(3);
            }
          }
        }
      }
      //debug prints
      if(DEBUG_MODE == 1){
        Serial.print("RPM =\t");
        Serial.print(itcToRpm(itc));  
        Serial.print("\t TARGET =\t");
        Serial.print(itcCurrentTarget);
        Serial.print("\t ITC =\t");
        Serial.print(itc);
        Serial.print("\t POSITION DIFF =\t");
        Serial.print(itcPositionDiff);
        Serial.print("\t PWM =\t");
        Serial.print(currentPwm);
        Serial.print("\t PWMD =\t");
        Serial.println(currentPwmDelta);
      }
      if(DEBUG_MODE == 2){
        Serial.print(itcToRpm(itc));  
        Serial.print("  ");
        Serial.println(itcToRpm(itcCurrentTarget));
      }
      slowLoopMillis = millis();
    }
    handleBuzzer();
  }  
}

void buzzerBeep (int beepTimes){
  buzzerBeepCounter = beepTimes*2;
}

void handleBuzzer (){
  if(buzzerBeepCounter > 0){
    if (millis() - buzzerMillis >= 250){
      if(buzzerBeepState == 0){
        digitalWrite(BUZZER, HIGH);
        buzzerBeepState = 1;
      }else{
        digitalWrite(BUZZER, LOW);
        buzzerBeepState = 0;
      }
      buzzerBeepCounter = buzzerBeepCounter - 1;
      buzzerMillis = millis();
    }
  }
}

int rpmToItc(double rpmToConvert){
  return int((rpmToConvert * GEARRATIO * ENCODERIPR) / (60000000/itcSampleRate));
}

double itcToRpm(double itcToConvert){
  return double(itcToConvert * (60000000/itcSampleRate)) / double(ENCODERIPR) / double(GEARRATIO);
}


void readEncoder(){
  revolutions++;
}