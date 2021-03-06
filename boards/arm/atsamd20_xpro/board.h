/*
 * Copyright (c) 2018 Sean Nyekjaer
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef __INC_BOARD_H
#define __INC_BOARD_H

#include <soc.h>

#define CONFIG_SPI_SAM0_SERCOM0_PADS \
	(SERCOM_SPI_CTRLA_DIPO(0) | SERCOM_SPI_CTRLA_DOPO(2))

#define CONFIG_UART_SAM0_SERCOM3_PADS \
	(SERCOM_USART_CTRLA_RXPO_PAD3 | SERCOM_USART_CTRLA_TXPO_PAD2)

#define CONFIG_UART_SAM0_SERCOM4_PADS \
	(SERCOM_USART_CTRLA_TXPO_PAD0 | SERCOM_USART_CTRLA_RXPO_PAD1)

#endif /* __INC_BOARD_H */
