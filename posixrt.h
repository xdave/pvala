#ifndef __POSIXRT__
#define __POSIXRT__

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#define os_atomic_int_inc(p) (__sync_fetch_and_add(p, 1 ))
#define os_atomic_int_dec_and_test(p) ((__sync_sub_and_fetch (p, 1)) == 0)

typedef struct _Type Type;
typedef struct _Object Object;
typedef struct _SignalHandler SignalHandler;

typedef void (*SignalMarshaller)(void *instance, void *callback,
				 void *user_data, void *result, va_list args);
typedef void (*NotifyCallback)(void* user_data);

struct _Type {
	Type *base_type;
	void  (*finalize)(void *instance);
	void *(*get_interface)(void *instance, void *interface_type);
};

struct _Object {
	Type *type;
	volatile unsigned int ref_count;
};

struct _SignalHandler {
	void (*callback)();
	void (*disconnect_notify)(void *user_data);
	void *user_data;
	SignalHandler *next;
};

extern Type *object_type;

static inline void *object_ref(void *instance) {
	Object *self;
	self = (Object *)instance;
	os_atomic_int_inc(&self->ref_count);
	return instance;
}

static inline void object_unref(void *instance) {
	Object *self;
	self = (Object *) instance;
	if (os_atomic_int_dec_and_test(&self->ref_count)) {
		self->type->finalize(self);
		free(self->type);
		free(self);
	}
}

static inline unsigned long object_signal_connect(void *instance,
						  SignalHandler **handlers,
						  void *callback,
						  void *user_data,
						  void *disconnect_notify) {
	SignalHandler *signal;
	signal = malloc(sizeof(SignalHandler));
	signal->callback = callback;
	signal->user_data = user_data;
	signal->disconnect_notify = disconnect_notify;
	signal->next = NULL;
	if ((*handlers) == NULL) {
		*handlers = signal;
	} else {
		SignalHandler *last;
		last = *handlers;
		while (last->next != NULL) {
			last = last->next;
		}
		last->next = signal;
	}
	return (unsigned long)signal;
}

static inline void object_signal_emit(void *instance, SignalHandler *handler,
				      SignalMarshaller marshaller, void *result,
				      ...) {
	va_list ap;
	va_list args;
	void *marshaller_result;
	marshaller_result = NULL;
	va_start(ap, result);
	va_copy(args, ap);
	while (handler != NULL) {
		marshaller(instance, handler->callback, handler->user_data,
				marshaller_result, args);
		handler = handler->next;
	}
	if (result != NULL) {
		result = marshaller_result;
	}
	va_end(args);
	va_end(ap);
}

static inline void object_signal_disconnect_callback(void *instance,
						     SignalHandler **handlers,
						     void *callback) {
	SignalHandler *handler;
	SignalHandler *prev;
	handler = *handlers;
	prev = NULL;
	while (handler != NULL) {
		if (handler->callback == callback) {
			SignalHandler *tmp;
			tmp = handler;
			if (prev == NULL) {
				*handlers = handler->next;
			} else {
				prev->next = handler->next;
			}
			handler = handler->next;
			if (tmp->disconnect_notify != NULL) {
				tmp->disconnect_notify(tmp->user_data);
			}
			free(tmp);
		} else {
			prev = handler;
			handler = handler->next;
		}
	}
}

static inline void object_instance_init(void *instance) {
	((Object *)instance)->ref_count = 1;
}


static inline int object_is_subtype_of(void *instance, void *type) {
	Object *self;
	self = (Object *)instance;
	if (self->type == type) {
		return 1;
	} else {
		Type *current_type;
		current_type = ((Type *)self->type)->base_type;
		while (current_type != NULL) {
			if (current_type == type) {
				return 1;
			}
			current_type = current_type->base_type;
		}
		/*check interfaces*/
		if (((Type *)(self->type))->get_interface(instance, type) != NULL) {
			return 1;
		}
	}
	return 0;
}

static inline void object_finalize(void *instance) {
}

static inline void *object_get_interface(void *instance, void *interface_type) {
	return NULL;
}

static inline void object_type_init(void) {
	if (object_type == NULL) {
		object_type = (Type *)calloc(1, sizeof(Type));
		object_type->finalize = object_finalize;
		object_type->get_interface = object_get_interface;
	}
}

#endif /* __POSIXRT__ */
