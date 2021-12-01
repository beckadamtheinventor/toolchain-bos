#ifndef NETPKTCE_H
#define NETPKTCE_H

#include <stddef.h>
#include <stdbool.h>
#include <srldrvce.h>

/*********************************************************************************************************************************************
 *	@file netpktce.h
 *	@brief Defines the implementation of TI-ONP
 *
 *	TI-ONP is an acronym for TI Open Network Protocol.
 *	It is a bare-bones open-source protocol for sending packets to a connected host using some networking device.
 *
 *	Provides an implementation of a basic packetization standard for the TI-84+ CE.
 *	The "standard" is simply:
 *		- 3-byte size word indicating frame length (cannot be larger than the max packet size specified during Initialization)
 *		- The data section of arbitrary (but bounded) length.
 *		- * subject to change if more header data is needed
 *
 *	@author Anthony @e ACagliano Cagliano
 **********************************************************************************************************************************************/
 
/**************************************************************************************************************************************
 * @enum Networking Modes
 *
 * Specifies the subsystem (device) to enable for networking. As of now, only options are @b NET_MODE_SERIAL.
 **************************************************************************************************************************************/
enum _device_types {
	DEVICE_NONE,		/**< indicates that no device is set. This is a default state. */
    DEVICE_SERIAL,		/**< specifees the Serial/USB subsystem to be used for networking. */
};

/***************************************************************************************************************************
 * @brief Saves internally a reference to an initialized networking device for transmission.
 *
 * @param dev_type Specifies the type of device to use. Use the values from @b enum @b _device_types.
 * @param dev_ref Pointer to the device reference structure. (Ex: @e srl_device_t* for serial)
 * @param buf_len Size of the internal buffer reserved for the specified device
 * 		(Ex: for serial, the total size of the serial buffer).
 * @note Here is an example of code, showing what the arguments mean:
 * 	@code
 * 	// usb init stuff
 * 	srl_device_t srl_dev;
 * 	uint8_t srl[4096];
 * 	if( srl_Open(&srl_dev, usb_dev, srl, 4096, SRL_INTERFACE_ANY, 9600 ) return 0;
 * 	if( !pl_SetDevice(DEVICE_SERIAL, &srl_dev, 4096) ) return 0;
 * 	// continue with the packet lib
 * 	@endcode
 ***************************************************************************************************************************/
bool pl_SetDevice(uint8_t dev_type, void *dev_ref, size_t buf_len);

/***************************************************************************************************************************************
 * @brief Returns a pointer to the internal device events handler.
 *
 * Due to lack of interrupt support on the TI-84+ CE, in some cases you may be required to call an
 * event handler stub in a tick-loop. In this case, return and use a function pointer like so. Note that because
 * the handler may sometimes be NULL (no handler) you should check if the hander is not NULL
 * before trying to call it.
 * @code
 * void (*handler)(bool block) = pl_GetAsyncProcHandler();
 * if(handler) handler(true|false)
 * @endcode
 * @note The handler parameter specifies if the call to the async process handler should be blocking or non-blocking.
 * 		Non-blocking runs once and then returns. Blocking runs for the set timeout (default of 50ms).
 * @note This library will call the handler function on its own at some points, namely during pl_SendPacket() and
 * 		pl_ReadPacket(). If you have no need for consistent device processing, you can probably rely on the library's
 * 		calling of it; however if you are coding a more dynamic networking application that exchanges large quantities
 * 		of data, it may be helpful to tick it yourself, even if it may not be needed, simply to ensure that you are
 * 		emptying out your send and receive buffers as quickly as possible.
 * @returns Pointer to the internal asyncronous subsystem event handler that can be run in blocking or non-blocking mode.
 * 		For USB/Serial, a pointer to a function that loops usb_HandleEvents() (either once or for a timeout).
 *****************************************************************************************************************************************/
void* pl_GetAsyncProcHandler(void);

/******************************************************************************************************
 * @brief Initializes an optional send queue for outgoing messages.
 *
 * @param queue_buf Pointer to a buffer to use as the outgoing message queue.
 * @param queue_len Length of the @b queue_buf.
 * @note Assert @b queue_len >= (( @b buf_len / 2 ) - 3). @see pl_SetDevice().
 *******************************************************************************************************/
bool pl_InitSendQueue(uint8_t *queue_buf, size_t queue_len);

/****************************************************************************************************
 * @brief Writes a packet segment to the send queue.
 *
 * @param data Pointer to the data to write to the queue.
 * @param len Length of @b data.
 * @returns True if success. False if failure.
 * @note The queue is used to contruct a single packet, not to queue multiple packets.
 * 		When you have queued all segments of a packet, then do:
 * 		@code
 * 		pl_SendPacket(NULL, 0);
 * 		@endcode
 * 		to send the queue. It will empty out the queue, reset its length to 0,
 * 		and await new packet segments.
 ********************************************************************************************************/
bool pl_QueueSendPacketSegment(uint8_t *data, size_t len);

/**********************************************************************************************************************************
 * @brief Sends a packet or sends the the contents of the send queue.
 *
 * Attempts to send data via the whatever device is passed in pl_SetDevice().
 * Determines the maximum packet size, and breaks the input into multiple frames.
 * Each "frame" starts a blocking asyncronous event handler with a timeout of 50ms, giving the device time
 * to clear out any backlog in the send buffer. After this timeout, a 3-byte size word, followed by the frame data
 * is written to the output buffer.
 *
 * @param data Pointer to the buffer containing the packet to send. Alternatively, @b NULL to send the queue.
 * @param len The length of the packet at @b data. Can be 0 if @b data is NULL.
 * @returns The length of the packet sent. Will loop sending multiple packet frames until the passed buffer
 * 		or queue is fully sent or an error occurs.
 * @note If at any point a frame reports that the number of bytes sent does not match what is expected,
 * 		an error, namely buffer limit, is assumed to have occured. The packet send loop immediately breaks,
 * 		returning the size that was successfully sent. It is up to the user if it is important to them to check
 * 		for and possibly handle this error condition or if it can simply be ignored.
 ********************************************************************************************************************************/
size_t pl_SendPacket(uint8_t *data, size_t len);

/***************************************************************************************************************************************
 * @brief Reads a number of bytes from the subsystem.
 *
 * @param dest Pointer to a buffer to read bytes to. Must be large enough to hold the largest
 * 		packet your application uses.
 * @note This function defaults to a non-blocking read, meaning it checks if there is a full packet
 * 		available in the receive buffer and then immediately returns to the caller.
 * 		You may set this to a blocking read by using the pl_SetReadTimeout() function.
 * @returns Size read if packet available. 0 otherwise.
 * @note Because the packet header contains a size word, there is no need to pass a read size.
 * 		The protocol will alternate between attempting to read a @b size_t (3 bytes) and attempting
 * 		to read the length the last size_t indicated.
 * @note Like the send function, the read function can also support packet overflow, but it handles it differently.
 * 		In this case, once the expected size is known, the library will attempt to read the @b least of either: the
 * 		expected size or the receive buffer length. After performing the read, it will reduce the expected size by
 * 		the last read. If the expected size is now 0, the packet is complete, and it awaits a new size. However, if
 * 		the expected size is still non-zero, it continues to await more packet data until the expected size is reached.
 ***************************************************************************************************************************************/
size_t pl_ReadPacket(uint8_t *dest);

/*****************************************************************************************************
 * @brief Sets the timeout for the Async device process handler.
 * @note The async handler is invoked once when pl_SendPacket() is called.
 * 		It can also be invoked by the user after returning pl_GetAsyncProcHandler().
 * @note Async timeout defaults to 50ms but can be altered by the user via this function.
 * @param timeout The timeout to set, in milliseconds. Pass 0 to set non-blocking.
 *****************************************************************************************************/
void pl_SetAsyncTimeout(size_t timeout);

/****************************************************************************************************
 * @brief Sets the timeout for reading a packet.
 * @note The packet read timeout defaults to 0, or non-blocking, but can be altered by
 * 		the user via this function.
 * @param timeout The timeout to set, in milliseconds. Pass 0 to set non-blocking.
 ****************************************************************************************************/
void pl_SetReadTimeout(size_t timeout);

#endif
