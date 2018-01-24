/*
** Axcell
** Copyright (C) 2018 tacigar
*/

#ifndef AXCELL_MQTT_TOKEN_H
#define AXCELL_MQTT_TOKEN_H

#include <MQTTClient.h>
#include <lua.h>

#define MQTT_TOKEN_CLASS "axcell.mqtt.Token"

typedef struct Token
{
    MQTTClient m_client;
    MQTTClient_deliveryToken m_token;
} Token;

Token *tokenCreate(lua_State *L, MQTTClient client, int tk);

#endif /* AXCELL_MQTT_TOKEN_H */
