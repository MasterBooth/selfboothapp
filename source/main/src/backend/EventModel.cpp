#include "EventModel.h"

EventModel::EventModel(DatabaseManager *dbManager, QObject *parent)
    : QAbstractListModel(parent), m_dbManager(dbManager) {
  refresh();
}

int EventModel::rowCount(const QModelIndex &parent) const {
  Q_UNUSED(parent);
  return m_events.count();
}

QVariant EventModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() >= m_events.count())
    return QVariant();

  const Event &event = m_events.at(index.row());

  switch (role) {
  case IdRole:
    return event.id;
  case NameRole:
    return event.name;
  case LocationRole:
    return event.location;
  case EventDateRole:
    return event.eventDate;
  case UpdatedAtRole:
    return event.updatedAt;
  case CaptureModeRole:
    return event.captureMode;
  case DigitalPropsRole:
    return event.digitalProps;
  case BeautyFilterRole:
    return event.beautyFilter;
  case WatermarkRole:
    return event.watermark;
  case PostProcessingRole:
    return event.postProcessing;
  case ThumbnailPathRole:
    return event.thumbnailPath;
  case SelectedLayoutRole:
    return event.selectedLayout;
  case CountdownDurationRole:
    return event.countdownDuration;
  case FirstShotCountdownRole:
    return event.firstShotCountdown;
  case NextShotCountdownRole:
    return event.nextShotCountdown;
  case ShotIntervalRole:
    return event.shotInterval;
  case AutoCutRole:
    return event.autoCut;
  default:
    return QVariant();
  }
}

QHash<int, QByteArray> EventModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[IdRole] = "eventId";
  roles[NameRole] = "name";
  roles[LocationRole] = "location";
  roles[EventDateRole] = "eventDate";
  roles[UpdatedAtRole] = "updatedAt";
  roles[CaptureModeRole] = "captureMode";
  roles[DigitalPropsRole] = "digitalProps";
  roles[BeautyFilterRole] = "beautyFilter";
  roles[WatermarkRole] = "watermark";
  roles[PostProcessingRole] = "postProcessing";
  roles[ThumbnailPathRole] = "thumbnailPath";
  roles[SelectedLayoutRole] = "selectedLayout";
  roles[CountdownDurationRole] = "countdownDuration";
  roles[FirstShotCountdownRole] = "firstShotCountdown";
  roles[NextShotCountdownRole] = "nextShotCountdown";
  roles[ShotIntervalRole] = "shotInterval";
  roles[AutoCutRole] = "autoCut";
  return roles;
}

void EventModel::refresh() {
  beginResetModel();
  m_events = m_dbManager->getAllEvents();
  endResetModel();
  emit eventsChanged();
}

void EventModel::searchEvents(const QString &query) {
  beginResetModel();
  if (query.isEmpty()) {
    m_events = m_dbManager->getAllEvents();
  } else {
    m_events = m_dbManager->searchEvents(query);
  }
  endResetModel();
  emit eventsChanged();
}

int EventModel::getEventId(int index) const {
  if (index >= 0 && index < m_events.count()) {
    return m_events.at(index).id;
  }
  return -1;
}

QVariantMap EventModel::getEventData(int index) const {
  QVariantMap map;
  if (index >= 0 && index < m_events.count()) {
    const Event &event = m_events.at(index);
    map["id"] = event.id;
    map["name"] = event.name;
    map["location"] = event.location;
    map["eventDate"] = event.eventDate;
    map["captureMode"] = event.captureMode;
    map["digitalProps"] = event.digitalProps;
    map["beautyFilter"] = event.beautyFilter;
    map["watermark"] = event.watermark;
    map["postProcessing"] = event.postProcessing;
    map["rawPath"] = event.rawPath;
    map["finalPath"] = event.finalPath;
    map["selectedLayout"] = event.selectedLayout;
    map["countdownDuration"] = event.countdownDuration;
    map["shotInterval"] = event.shotInterval;
    map["autoCut"] = event.autoCut;
  }
  return map;
}
