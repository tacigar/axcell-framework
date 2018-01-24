/*
** Axcell
** Copyright (C) 2018 tacigar
*/

#ifndef AXCELL_MQTT_MESSAGE_H
#define AXCELL_MQTT_MESSAGE_H

#include <MQTTClient.h>
#include <lua.h>

void messageCreate(lua_State *L, MQTTClient_message *message);

#endif /* AXCELL_MQTT_MESSAGE_H */
