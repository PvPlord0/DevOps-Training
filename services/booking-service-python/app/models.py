from pydantic import BaseModel


class BookingRequest(BaseModel):
    userId: str
    eventId: int


class ReviewRequest(BaseModel):
    text: str
